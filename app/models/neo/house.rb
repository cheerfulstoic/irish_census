module Neo
  class House
    include Neo4j::ActiveNode
    set_mapped_label_name 'House'

    property :census_id
    property :census_year
    property :house_number

    has_one :out, :townland_street, type: 'IN', model_class: 'Neo::TownlandStreet'

    has_many :in, :residents, origin: :residence, model_class: 'Neo::Resident'

    has_many :out, :similarity_candidates_rel, type: :similarity_candidate, model_class: 'Neo::House'

    include Comparable

    def <=>(other)
      house_number.to_i <=> other.house_number.to_i
    end

    def name
      house_number
    end

    def similarity_candidates
      residents
        .similarity_candidates_rel
        .residence(:house2)
        .query
        .with(:house2, 'count(*) AS count')
        .order('count DESC')
        .where('count > 1')
        .pluck(:house2)
    end

    # Returns a query that matches the current house (house1) and a variable second house (house2)
    # Two residents in each house are matched directly to two residents in the other house
    # via a :similarity_candidate relationship.  The query variables are as follows:
    # 
    # h1_r1-[sc1:similarity_candidate]-h2_r1
    # h1_r2-[sc2:similarity_candidate]-h2_r2
    def resident_relation_match_query
      @resident_relation_match_query ||= 
        query_as(:house1)
        .match(house2: :House)
        .match('house1<-[:LIVES_IN]-(h1_r1:Resident)-[sc1:similarity_candidate]-(h2_r1:Resident)-[:LIVES_IN]->house2')
        .match('house1<-[:LIVES_IN]-(h1_r2:Resident)-[sc2:similarity_candidate]-(h2_r2:Resident)-[:LIVES_IN]->house2')
        .where('ID(h1_r1) < ID(h1_r2)')
        .where('ID(h2_r1) < ID(h2_r2)')
    end


    def resident_same_relation_match_query
      resident_relation_match_query
        .match("path1=h1_r1-[relationship1:#{Resident::RELATIONS_RELATIONSHIP_TYPES.join('|')}*1..2]-h1_r2")
        .match("path2=h2_r1-[relationship2:#{Resident::RELATIONS_RELATIONSHIP_TYPES.join('|')}*1..2]-h2_r2")
        .with(
          'house1, h1_r1, sc1, h1_r2, house2, h2_r1, sc2, h2_r2',
          'EXTRACT(rel IN relationships(path1) | type(rel)) AS types1',
          'EXTRACT(rel IN relationships(path2) | type(rel)) AS types2')
        .where('types1 = types2')
    end

    def resident_sibling_match_query
      resident_relation_match_query
        .match('h1_r1-[:born_to]->(h1_parent)<-[:born_to]-h1_r2')
        .match('h2_r1-[:born_to]->(h2_parent)<-[:born_to]-h2_r2')
        .match('h1_parent-[:similarity_candidate]-h2_parent')
    end

    def resident_other_sibling_match_query
      resident_relation_match_query
        .match('h1_r1-[:born_to]->(h1_parent)<-[:born_to]-h1_r2')
        .match('h2_r1-[:sibling_of]-h2_r2')
        #.match('h1_r1-[:sibling_of]-h1_r2')
        #.match('h2_r1-[:born_to]->(h2_parent)<-[:born_to]-h2_r2')
    end

    def resident_grandparent_match_query
      resident_relation_match_query
        .match('h1_r1-[:born_to]->()-[:born_to]->h1_r2')
        .match('h1_r1-[:born_to]->()-[:born_to]->h1_r2')
    end

    RELATION_METHOD_SCORES = {
      same_relation: 0.3,
      sibling: 0.6,
      other_sibling: 0.7,
      grandparent: 0.6
    }

    def refresh_similarity_candidate_rels
      self.similarity_candidates_rel = []
      RELATION_METHOD_SCORES.each do |type, weight|
        send("resident_#{type}_match_query")
          .params(weight: weight)
          .with(:house1, :house2, '{weight} * sum(sc1.total + sc2.total) AS total_total')
          .merge('house1-[house_sc:similarity_candidate]->house2')
          .on_create_set('house_sc.total = total_total')
          .on_match_set('house_sc.total = house_sc.total + total_total')
          .break
          .set("house_sc.`#{type}` = total_total").exec
      end
    end

    def similar_houses
      Neo::Resident.populate_latitude_longitude(residents)
      residents.map do |resident|
        resident.similarity_candidates.sort_by {|candidate| resident.similarity_to(candidate) }.reverse[0,15].map(&:residence)
      end.flatten.counts.select {|house, count| count > 1 }.sort_by(&:last).reverse
    end

    def match_residents(other_house)
      pairs = residents.map {|r1| other_house.residents.map {|r2| [r1, r2] } }.flatten(1)

      pairs += residents.map {|r1| [r1, nil] }
      pairs += other_house.residents.map {|r2| [nil, r2] }

      found = []
      pairs.sort_by do |r1, r2|
        if r1 && r2
          if r1.identified_as == r2
            1
          else
            r1.similarity_to(r2).tap do |s|
              puts 's', s, "#{r1.forename} #{r1.surname} - #{r2.forename} #{r2.surname}"
            end
          end
        else
          0.001
        end
      end.reverse.select do |pair|
        (found & pair).empty?.tap do
          found += pair
          found.compact!
        end
      end
    end
  end
end
