

module RakeImportHelpers
  NEO4J_PATH = Rails.root.join('db/neo4j/development')

  def run_cql(path)
    command = "#{NEO4J_PATH.join('bin/neo4j-shell')} -path #{NEO4J_PATH.join('data/graph.db')} -file #{path}"
    puts "Running script: #{command}"
    `#{command}`
    puts "Script run"
  end

  require 'digest'
  require 'socket'

  @@mutex = Mutex.new
  @@counter = 0

  def get_id
    @@mutex.lock
    begin
      count = @@counter = (@@counter + 1) % 0xFFFFFF
    ensure
      @@mutex.unlock rescue nil
    end
    machine_id = Digest::MD5.digest(Socket.gethostname).unpack("N")[0]
    process_id = RUBY_ENGINE == 'jruby' ? "#{Process.pid}#{Thread.current.object_id}".hash % 0xFFFF : Process.pid % 0xFFFF
    [ Time.now.to_i, machine_id, process_id, count << 8 ].pack("N NX lXX NX").unpack("H*")[0]
  end
end
include RakeImportHelpers

class ImportRenderer
  attr_accessor :county_name, :hierarchy_files, :resident_files, :census_year

  def initialize
    @erb = ERB.new(template_pathname.read)
  end

  def template_pathname
    Rails.root.join('app/views/rake/import_csv.cql.erb')
  end

  def result
    @erb.result(binding)
  end
end 


class Fetcher
  include HTTParty
  CACHE = ActiveSupport::Cache::FileStore.new(Rails.root.join('cache'))

  base_uri 'www.census.nationalarchives.ie'

  attr_reader :fetches

  def initialize
    @fetches = 0
    @threads = []
    @blocks = []
  end

  def response_thread(*parts)
    path_partial = parts.join('/')
    Thread.new do
      result = nil
      failed = false
      begin
        failed = false
        begin
          result = CACHE.fetch(path_partial) do
            puts "Time to party!"
            puts Time.now

            @fetches += 1

            path = "/pages/#{path_partial}"
            Timeout::timeout(10) do
              self.class.get(path, {}).tap {|r|  }
            end
          end
        rescue Exception => e
          failed = true
          puts "Error: #{e.message} (#{parts.inspect})"
        end
      end until not failed

      result
    end
  end

  def open_thread_count
    @threads.size
  end

  def wait_for_threads
    @threads.zip(@blocks).each_with_index do |(thread, block), index|
      if thread = thread.join(0.1)
        @threads.delete_at(index)
        @blocks.delete_at(index)

        block.call(Nokogiri::HTML(thread.value))
      end
    end
  end

  THREADS = 10
  def document(*parts, &block)
    if block
      @threads << response_thread(*parts)
      @blocks << block

      if @threads.size == THREADS
        wait_for_threads until @threads.size < THREADS
      else
        wait_for_threads
      end

    else
      Nokogiri::HTML(response_thread(*parts).value)
    end
  end
end



namespace :import do
  task :csv_to_db, [:years] => :environment do |task, args|
    run_cql(Rails.root.join('app/views/rake/create_indexes.cql'))

    require 'dm-migrations'

    DM::Resident # Bring into scope
    DataMapper.auto_migrate!

    years = args[:years] ? args[:years].split(',').map(&:to_i) : [1901, 1911]

    years.each do |year|
      Dir.glob("csv/#{year}/*.csv").each do |county_csv_path|
        county_name = File.basename(county_csv_path, '.csv')

        puts "Importing #{county_name} for #{year}..."

        hierarchy_files = []
        hierarchy_csvs = []

        resident_files = []
        resident_csvs = []

        hierarchy_rows = Set.new

        row_counter = 0

        CSV.parse(File.read(county_csv_path)) do |row|

          if row_counter.zero?
            resident_files << Tempfile.new("residents.csv")
            hierarchy_files << Tempfile.new("hierarchy.csv")
            putc '.'
            resident_csvs << CSV.open(resident_files.last.path, 'wb')
            hierarchy_csvs << CSV.open(hierarchy_files.last.path, 'wb')
          end

          hierarchy_row = row[0,7]

          if not hierarchy_rows.include?(hierarchy_row)
            hierarchy_csvs.last << hierarchy_row
            hierarchy_rows << hierarchy_row
          end

          resident_row = row[4,1] + row[8..-1]

          row_counter += 1
          row_counter = 0 if row_counter > 20_000

          resident_csvs.last << resident_row
        end

        hierarchy_files.each(&:close)
        hierarchy_csvs.each(&:close)
        resident_files.each(&:close)
        resident_csvs.each(&:close)

        puts
        puts "Created #{resident_files.size} resident files"

        import_cql_file = Tempfile.new('import.cql')
        import_renderer = ImportRenderer.new
        import_renderer.county_name = county_name
        import_renderer.census_year = year
        import_renderer.hierarchy_files = hierarchy_files
        import_renderer.resident_files = resident_files

        import_cql_file.write(import_renderer.result)
        import_cql_file.close

        puts "Copying data to PostgreSQL"
        resident_files.each do |residents_file|
          putc '.'
          conn = PG.connect(dbname: 'irish_census_development')
          conn.exec("
            COPY residents (census_id, uuid, surname, forename, age, sex, relation_to_head, religion, birthplace, occupation, literacy, irish_language, marital_status, specified_illness, years_married, children_born, children_living)
            FROM '#{residents_file.path}'
            WITH NULL ''
            DELIMITER ',' CSV;")
        end
        puts

        run_cql(import_cql_file.path)

        hierarchy_files.each(&:unlink)
        resident_files.each(&:unlink)
        import_cql_file.unlink
      end
    end
  end

  task :census_years, [:years] => :environment do |task, args|
    years = args[:years] ? args[:years].split(',').map(&:to_i) : [1901, 1911]

    batch_size = 7_000
    conn = PG.connect(dbname: 'irish_census_development')
    years.each do |year|
      puts "Processing #{year}"
      census_ids = House.where(census_year: year).query_as(:h).pluck(h: :census_id)
      census_ids.in_groups_of(batch_size, false).each do |group|
        putc '.'
        conn.exec("UPDATE residents SET census_year = #{year} WHERE census_id IN (#{group.join(',')});")
      end
      puts

    end
  end

  task :html_to_csv, [:years] do |task, args|
    years = args[:years] ? args[:years].split(',').map(&:to_i) : [1901, 1911]

    fetcher = Fetcher.new


    years.each do |year|

      fetcher.document(year).css('div#results_frame > ul:not(#breadcrumb) li').each do |li|
        link = li.css('a').first
        county = link.text
    #    next unless county == 'Cork'
        county_encoded = link['href'].split('/').reject(&:blank?)[-1]

        FileUtils.mkdir_p("csv/#{year}")
        CSV.open("csv/#{year}/#{county}.csv", "wb") do |county_csv|

          fetcher.document(year, county_encoded).css('div#results_frame > ul:not(#breadcrumb) li').each do |li|
            link = li.css('a').first
            ded = link.text
            ded_encoded = link['href'].split('/').reject(&:blank?)[-1]

            FileUtils.mkdir_p("csv/#{year}/#{county}")
            #CSV.open("csv/#{year}/#{county}/#{ded}.csv", "wb") do |ded_csv|

              fetcher.document(year, county_encoded, ded_encoded).css('div#results_frame > ul:not(#breadcrumb) li').each do |li|
                link = li.css('a').first
                townland_street = link.text
                townland_street_encoded = link['href'].split('/').reject(&:blank?)[-1]

                processed_census_ids = []
                finished_census_ids = []
                started_census_ids = []

                fetcher.document(year, county_encoded, ded_encoded, townland_street_encoded).css('div#results_frame > table tr').each do |row|
                  cells = row.css('td')
                  if cells.size > 0
                    house_number = cells[0].text
                    surnames = cells[1].text

                    occupants_link = cells[2].css('a')[0]
                    census_id = occupants_link['href'].split('/').reject(&:blank?)[-1]

                    original_census_link = cells[2].css('a')[1]
                    original_census_path = original_census_link['href']

                    next if processed_census_ids.include?(census_id)
                    processed_census_ids << census_id

                    fetcher.document(year, county_encoded, ded_encoded, townland_street_encoded, census_id) do |doc|
                      doc.css('div#results_frame > table tr').each do |row|
                        cells = row.css('td')
                        if cells.size > 0
                          data = [ded, ded_encoded, townland_street, townland_street_encoded, census_id, house_number, original_census_path, surnames, get_id] + cells.map(&:text) + (['-'] * (15 - cells.size))
                          data = data.map {|datum| ['-', ''].include?(datum.strip) ? nil : datum }
                          county_csv << data
                          #ded_csv << [townland_street, census_id, house_number, surnames] + cells.map(&:text) + (['-'] * (15 - cells.size))
                          surname = cells[0].text
                          forename = cells[1].text
                          age = cells[2].text.to_i

                          puts "#{year} > #{county} > #{ded} > #{townland_street} > ##{house_number} (#{surnames}) > #{forename} #{surname} (#{age})"
                        end
                      end

                      finished_census_ids << census_id
                    end

                  end

                end

              end

              fetcher.wait_for_threads until fetcher.open_thread_count == 0

            #end
          end
        end
      end

    end

  end
end
