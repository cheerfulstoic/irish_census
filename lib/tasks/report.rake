namespace :report do
  task :population_movement, [:ded, :census_year] => :environment do |task, args|
    # Cloghdonnell/Cloghdowell
    ded = DED.where(name: args[:ded]).first

    ded.townland_streets.houses.each do |house|

    end
  end
end
