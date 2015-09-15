# Bookmarks: 
# http://www.boards.ie/vbulletin/showthread.php?p=54802404
# http://www.fallingrain.com/world/EI/

namespace :process do
  def execute_queries_in_batch(queries, faraday_connection)
    statements = queries.map do |query|
      {
        statement: query.to_cypher,
        parameters: query.send(:merge_params)
      }
    end

    faraday_connection.post do |req|
      req.url '/db/data/transaction/commit'
      req.headers['Accept'] = 'application/json; charset=UTF-8'
      req.headers['Content-Type'] = 'application/json'
      req.headers['X-Stream'] = 'true'
      req.body = {statements: statements}.to_json
    end.tap do |response|
      if response.status != 200
        fail "ERROR: response status #{response.status}:\n#{response.body}"
      else
        response_data = JSON.parse(response.body)
        if response_data['errors'].size > 0
          error_string = response_data['errors'].map do |error|
            [error['code'], error['message']].join("\n")
          end.join("\n\n")

          fail "ERROR: Cypher response error:\n" + error_string
        end
      end
    end
  end

  task :link_residents => :environment do
    ded = Neo::DED.find('326c7810-5044-4234-8712-1f14ff707fa9')
#    ded = Neo::DED.find('218b2cd5-6713-4e4e-a5bd-b37d582a16b5')

    uri = URI.parse(Neo4j::Session.current.resource_url)
    faraday_connection = Faraday.new(:url => "#{uri.scheme}://#{uri.host}:#{uri.port}") do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    class Neo::Resident
      has_one :out, :same_as, type: :same_as, model_class: 'Neo::Resident'
    end

    ded_residents = ded.townland_streets(:townland_street).houses(:h).residents(:resident)

    # puts "Deleting calculated relationships..."
    # ded_residents.similarity_candidates_rel(:other, :rel).query.delete(:rel).exec
    ded_residents.same_as(:other, :rel).query.delete(:rel).exec

    # queries = []
    # puts "Setting similarity_candidate relationships..."
    # ded_residents.pluck(:townland_street, :resident).each do |townland_street, resident|
    #   resident.ded = ded
    #   resident.townland_street = townland_street

    #   puts "#{resident.forename} #{resident.surname}"

    #   base_query = resident.query_as(:resident).match(candidate: {Resident: {id: '{uuid}'}})
    #       .create("resident-[:similarity_candidate {score: {score}}]->candidate")

    #   resident.similarity_candidates.map {|candidate| [resident.similarity_to(candidate), candidate] }.sort_by(&:first).each do |score, candidate|
    #     queries << base_query.params(uuid: candidate.id, score: score)

    #     if queries.size > 1000
    #       puts 'Flashing query buffer...'
    #       execute_queries_in_batch(queries, faraday_connection)
    #       queries = []
    #     end

    #   end

    # end

    puts "Setting same_as relationships"
    [3, 2].each do |min_similar_residents|
      puts "Creating candidate same_as relationships"
      #MATCH (ded:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts:TownlandStreet)--(h:House)--(r:Resident)-[:similarity_candidate]-(r2:Resident)--(h2:House)
      #WITH h, h2, count(h2) AS count
      #ORDER BY count(h2) DESC
      #WHERE count >= 3
      #MATCH h--(r:Resident)-[rel:similarity_candidate]-(r2:Resident)--h2
      #WHERE not(r-[:same_as]-r2)
      #CREATE r-[:same_as {score: rel.score}]->r2
      ded_residents.similarity_candidates_rel.residence(:h2).query
        .with(:h, :h2, count: 'count(h2)')
        .order_by('count(h2) DESC')
        .break
        .where('count >= {min_similar_residents}')
        .params(min_similar_residents: min_similar_residents)
        .match('h<-[:LIVES_IN]-(r:Resident)-[rel:similarity_candidate]-(r2:Resident)-[:LIVES_IN]->h2')
        .where('not(r-[:same_as]-r2)')
        .create('r-[:same_as {score: rel.score}]->r2')
        .exec

      puts "Deleting similarity_candidate relationships where a same_as relationships has been created"
      #MATCH (ded:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts:TownlandStreet)--(h:House)--(r:Resident)-[:same_as]-(r2:Resident)
      #MATCH r-[rel:similarity_candidate]-()
      #DELETE rel
      #ded_residents.query.match('resident-[:same_as]-()').with(:resident).match('resident-[rel:similarity_candidate]-()').delete(:rel).exec

      puts "Removing duplicate same_as relationships"
      #MATCH (ded:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts:TownlandStreet)--(h:House)--(r:Resident)-[rel:same_as]-(:Resident)
      #WITH r, max(rel.score) AS max_score
      #MATCH r-[rel:same_as]-(r2:Resident)
      #WHERE rel.score < max_score
      #DELETE rel
      ded_residents.same_as(nil, :rel).query.with(:resident, max_score: 'max(rel.score)').match('resident-[rel:same_as]-(r2:Resident)').where('rel.score < max_score').delete(:rel).exec

      ded_residents.same_as(:r2, :rel).query.match('resident-[:same_as]-(r3:Resident)').with(:resident).break.match('resident-[rel:same_as]-()').delete(:rel).exec
    end

  end

  # Next step: Link relationships and match relationships to match people?

  task :link_relationships => :environment do

    Neo::DED.all.each do |ded|
      #class Neo::Resident
      #  include Neo4j::ActiveNode
      #  has_many :both, :spouse, type: :married_to, model_class: 'Neo::Resident'

      #  has_many :out, :parent, type: :born_to, model_class: 'Neo::Resident'
      #  has_many :in, :child, type: :born_to, model_class: 'Neo::Resident'
      #end

      ded_residents = ded.townland_streets(:townland_street).houses(:house).residents(:resident)

      {
        # Fundamental relationships (:married_to and :born_to)
        Wife: 'resident-[:married_to]->head',
        Husband: 'resident-[:married_to]->head',

        Son: 'resident-[:born_to]->head',
        Daughter: 'resident-[:born_to]->head',

        Father: 'resident<-[:born_to]-head',
        Mother: 'resident<-[:born_to]-head',

        # Secondary relationships
        'Grand Son': 'resident-[:grandchild_of]->head',
        'Grand Daughter': 'resident-[:grandchild_of]->head',

        Niece: 'resident-[:niece_nephew_of]->head',
        Nephew: 'resident-[:niece_nephew_of]->head',

        Aunt: 'resident<-[:niece_nephew_of]-head',
        Uncle: 'resident<-[:niece_nephew_of]-head',

        Brother: 'resident-[:sibling_of]->head',
        Sister: 'resident-[:sibling_of]->head',

        Cousin: 'resident-[:cousin_of]->head',

        'Son in Law': 'resident-[:child_in_law_of]->head',
        'Daughter in Law': 'resident-[:child_in_law_of]->head',

        'Father in Law': 'resident<-[:child_in_law_of]-head',
        'Mother in Law': 'resident<-[:child_in_law_of]-head',

        'Step Son': 'resident-[:step_child_of]->head',
        'Step Daughter': 'resident-[:step_child_of]->head',

        'Step Father': 'resident<-[:step_child_of]-head',
        'Step Mother': 'resident<-[:step_child_of]-head',

      }.each do |relation_to_head, relationship_match|
        # Temporary
        if relation_to_head.in?([:Niece, :Nephew])
          ded_residents.
            where(relation_to_head: relation_to_head.to_s).
            query.
            match("house<-[:LIVES_IN]-(head:Resident {relation_to_head: 'Head of Family'}), head<-[rel:niece_of|nephew_of]-()").
            delete(:rel).
            exec
        end
        # END Temporary

        ded_residents.
          where(relation_to_head: relation_to_head.to_s).
          query.
          match("house<-[:LIVES_IN]-(head:Resident {relation_to_head: 'Head of Family'})").
          merge(relationship_match).
          exec
      end


    end

    # Find residents with a similarity candidate link between the two DEDs known to be the same
    # MATCH
    #    (ded1:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts1:TownlandStreet)--(h1:House)--(r1:Resident),
    #    (ded2:DED {uuid: '218b2cd5-6713-4e4e-a5bd-b37d582a16b5'})--(ts2:TownlandStreet)--(h2:House)--(r2:Resident),
    #    r1-[rel:similarity_candidate]-r2
    #  WHERE not(r1-[:same_as]-()) AND not(r2-[:same_as]-()) and r1.age >= 10
    #  RETURN rel.score, r1.forename, r2.forename, r1.surname, r2.surname, r1.age, r2.age, abs(10 - abs(r1.age - r2.age)) ORDER BY rel.score DESC

    # Find residents with at least two children links
    # MATCH (ded:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts:TownlandStreet)--(h:House)--(r1:Resident)-[:born_to]->(parent1:Resident), r1-[:same_as]-(r2:Resident)-[:born_to]->(parent2:Resident) WHERE parent1.sex = parent2.sex AND not(parent1-[:same_as]-parent2) WITH DISTINCT parent1, parent2 MATCH parent1<-[:born_to]-(r1:Resident)-[rel:same_as]-(r2:Resident)-[:born_to]->parent2 RETURN parent1, parent2, count(rel) ORDER BY count(rel) DESC


    # MATCH (ded1:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts1:TownlandStreet)--(h1:House)--(r1:Resident)-[:same_as]-(r2:Resident)--(h2:House) RETURN h1.census_id AS census_id1, r1.forename AS forename1, r1.surname AS surname1, r1.age AS age1, h2.census_id AS census_id2, r2.forename AS forename2, r2.surname AS surname2, r2.age AS age2
    # UNION
    # MATCH (ded1:DED {uuid: '326c7810-5044-4234-8712-1f14ff707fa9'})--(ts1:TownlandStreet)--(h1:House)--(r1:Resident) WHERE not(r1-[:same_as]-()) RETURN h1.census_id AS census_id1, r1.forename AS forename1, r1.surname AS surname1, r1.age AS age1, null AS census_id2, null AS forename2, null AS surname2, null AS age2
    # UNION
    # MATCH (ded1:DED {uuid: '218b2cd5-6713-4e4e-a5bd-b37d582a16b5'})--(ts1:TownlandStreet)--(h1:House)--(r1:Resident) WHERE not(r1-[:same_as]-()) RETURN null AS census_id1, null AS forename1, null AS surname1, null AS age1, h1.census_id AS census_id2, r1.forename AS forename2, r1.surname AS surname2, r1.age AS age2


  end
end
