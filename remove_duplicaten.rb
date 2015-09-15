where_clause = %w(forename
                  surname
                  age
                  sex
                  census_year
                  birthplace
                  irish_language
                  literacy
                  marital_status
                  occupation
                  relation_to_head
                  religion).map do |prop|
  "r1.#{prop} = r2.#{prop}"
end.join(' AND ')

Neo::DED.all.inject(0) do |sum, ded|
  puts 'sum', sum
  sum + ded.townland_streets
    .houses(:h)
    .residents
    .query_as(:r1)
    .match('h<-[:LIVES_IN]-(r2:Resident)')
    .where('ID(r1) < ID(r2)')
    .where(where_clause)
    .count
end






MATCH (ded:DED) WHERE ID(ded) = 451
MATCH ded--(ts:TownlandStreet)--(h:House)--(r1:Resident), h--(r2:Resident)
WHERE ID(r1) < ID(r2) AND (r1.forename = r2.forename AND r1.surname = r2.surname AND r1.age = r2.age AND r1.sex = r2.sex AND r1.census_year = r2.census_year AND r1.birthplace = r2.birthplace AND r1.irish_language = r2.irish_language AND r1.literacy = r2.literacy AND r1.marital_status = r2.marital_status AND r1.occupation = r2.occupation AND r1.relation_to_head = r2.relation_to_head AND r1.religion = r2.religion)
OPTIONAL MATCH r2-[r]-()
DELETE r2, r