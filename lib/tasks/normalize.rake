   # This code is based directly on the Text gem implementation
     # Returns a value representing the "cost" of transforming str1 into str2
     def levenshtein_distance str1, str2
       s = str1
       t = str2
       n = s.length
       m = t.length
       max = n/2

         return m if (0 == n)
       return n if (0 == m)
       return n if (n - m).abs > max

         d = (0..m).to_a
       x = nil

         n.times do |i|
             e = i+1

             m.times do |j|
                 cost = (s[i] == t[j]) ? 0 : 1
               x = [
                        d[j+1] + 1, # insertion
                        e + 1,      # deletion
                        d[j] + cost # substitution
                     ].min
               d[j] = e
               e = x
             end

             d[m] = x
         end

         return x
     end
#
# Notes:
# Standardize ["Grand Child", "Child", "Adopted Child", "Adopted"] based on sex
# Figure out "Scholar" as relationToHead (probably same as Child?)
#

require 'highline/import'

namespace :normalize do
  task :prompt, [:field] => :environment do |task, args|
    field = args[:field]

    mapping_file = "config/#{field}_mapping.yaml"
    puts "Loading mapping"
    mapping = (YAML.load(File.read(mapping_file)) rescue {})

    puts "Loading counts"
    #results = Neo::Resident.query_as(:r).return("r.#{field} AS value, count(r.#{field}) AS count").to_a
    struct = Struct.new(:value, :count)
    results = Ar::Resident.group(field).count.map {|value, count| struct.new(value, count) }
    puts "Counts loaded"

    File.open("config/#{field}_counts.yaml", 'w') {|f| f << results.to_yaml }

    results = results.reject {|result| mapping[result.value] }.sort_by(&:count).reverse

    input = ''
    while results.size > 0
      begin
        current_result = results.shift
      end while mapping.keys.include?(current_result.value)

      next if current_result.value.nil?

      unique_values = mapping.values.uniq

      puts
      puts "Choices:"
      unique_values.each_with_index do |value, index|
        puts "#{index}> #{value}#{value.downcase == current_result.value.downcase ? ' !!!!!!!!' : ''}"
      end
      puts "Current unmapped value: #{current_result.value} (#{current_result.count} occurances)"

      puts "Suggestions:"
      distances = mapping.keys.each_with_object({}) do |key, distances|
        distances[key] = levenshtein_distance(current_result.value, key)
      end

      distances.select {|k, d| d < 8 }.sort_by(&:last).uniq {|k, d| mapping[k] }[0,10].each do |key, distance|
        value = mapping[key]
        puts " #{unique_values.index(value)}>  #{value} (distance: #{distance})"
      end

      print "(#{results.size} more / 'QUIT' to quit) > "
      input = STDIN.gets

      choice = case input.chomp
      when 'QUIT'
        break
      when /^\d+$/
        unique_values[input.to_i]
      when ''
        current_result.value
      else
        input
      end

      mapping[current_result.value] = choice
      File.open(mapping_file, 'w') {|f| f << mapping.to_yaml }
    end

    puts mapping.to_yaml
  end

  namespace :residents do
    task :field, [:field] => :environment do |t, args|
      #pg_conn = PG.connect(dbname: 'irish_census_development')

      YAML.load(Rails.root.join("config/#{args.field}_mapping.yaml").read).each do |current_value, new_value|
        next if current_value == new_value

        puts "Updating '#{current_value}' to '#{new_value}'"

        puts 'Updating Neo4j'
        while Neo::Resident.where(args.field => current_value).count > 0
          putc '.'
          Neo::Resident.where(args.field => current_value).query_as(:resident).with(:resident).limit(50_000).break.set(resident: {args.field => new_value, "original_#{args.field}" => current_value}).exec
        end
        puts

        #uuids = Ar::Resident.where(args.field => current_value).pluck(:uuid)

        #puts 'Updating PostgreSQL'
        #pg_conn.exec("UPDATE residents SET #{args.field} = '#{new_value.gsub("'", "''")}' WHERE #{args.field} = '#{current_value.gsub("'", "''")}';")

        #puts 'Reindexing elasticsearch'
        #Ar::Resident.where(uuid: uuids).reindex

      end
    end

    task :relation_to_head => :environment do

    end

    task :default => [:relation_to_head] do

    end
  end
end

