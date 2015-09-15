module ResidentCommon
  extend ActiveSupport::Concern

  attr_accessor :latitude, :longitude

  def populate_latitude_longitude!
    self.class.populate_latitude_longitude([self]) unless latitude && longitude
  end

  def full_name
    forename + ' ' + surname
  end

  def similarity_to(other_resident)
    score = object_comparer.score(other_resident)

    score.zero? ? 0.0 : (1.0 / score)
  end

  def age_string
    "#{age}yo" if age.present?
  end

  def years_married_string
    "#{years_married}ym" if years_married.present?
  end


  def children_string
    "#{children_living}/#{children_born}" if children_born.present? && children_living.present?
  end

  AGE_SIMILARITY_DELTA = 15

  def similarity_candidates
    self.populate_latitude_longitude!

    where_clause = {sex: [sex, nil], census_year: other_census_year}
    if age = age_in(other_census_year)
      return [] if age < 0

      where_clause[:age] = (age - AGE_SIMILARITY_DELTA..age + AGE_SIMILARITY_DELTA).to_a + [nil]
    end

    self.class.search("#{forename} #{surname}", misspellings: {edit_distance: 4}, where: where_clause).to_a.tap do |candidates|
      puts "#{candidates.size} candidates!"

#    query = Ar::Resident.where(census_year: other_census_year).where('sex = ? OR sex IS NULL', sex).where("forename % ? AND surname % ?", forename, surname)
#    query = query.age_candidates(age_in(other_census_year))
#    query.to_a.tap do |candidates|
      # self.class.populate_latitude_longitude(candidates)
      # self.class.populate_ded_and_townland_streets(candidates)
    end
  end

  module ClassMethods
    def populate_latitude_longitude(residents)
      residents_by_uuid = residents.index_by(&:id)
      Neo::Resident.where(id: residents.map(&:id)).query_as(:resident).match("resident-[:LIVES_IN|IN*1..4]->(geo_node)").where("NOT(geo_node.latitude IS NULL) AND NOT(geo_node.longitude IS NULL)").pluck("resident.id, geo_node").each do |uuid, geo_node|
        resident = residents_by_uuid[uuid]
        resident.latitude = geo_node.latitude
        resident.longitude = geo_node.longitude
      end
    end

    def populate_ded_and_townland_streets(residents)
      residents_by_uuid = residents.index_by(&:id)

      Neo::Resident.where(id: residents.map(&:id)).query_as(:resident).match("resident-[:LIVES_IN]->(:House)-[:IN]->(ts:TownlandStreet)-[:IN]->(ded:DED)").pluck("resident.id, ded, ts").each do |uuid, ded, ts|
        resident = residents_by_uuid[uuid]
        resident.townland_street = ts
        resident.ded = ded
      end
    end

    def object_comparer
      @object_comparer ||= RecordLinkage::ObjectComparer.new do |config|
        field_scorers.each do |field, matcher|
          config.add_matcher(field, field, matcher, field_options[field])
        end
      end
    end

    RELATION_EQUIVILENCE_SCORES_BASE = {
      # Spouse
      ['<-married_to-', '-married_to->'] => 1.0,

      # Parent
      ['-born_to->', '-sibling_of-><-born_to-'] => 1.0,

      ['-born_to->', '-married_to->-child_in_law_of->'] => 0.8, # In-law from a former marriage?

      # Sibling
      ['-sibling_of->', '-born_to-><-born_to-'] => 1.0,

      # Aunt/Uncle
      ['-niece_nephew_of->', '-born_to-><-sibling_of-'] => 1.0,

      ['-niece_nephew_of->', '-cousin_of-><-born_to-'] => 0.0, # ?

      # Grandparent
      ['-grandchild_of->', '-born_to->-born_to->'] => 1.0,

      ['-grandchild_of->', '-grandchild_of-><-married_to-'] => 0.0, # ?
      ['-grandchild_of->', '-born_to->-step_child_of->'] => 0.0, # ?

      # Other guardian
      ['-born_to-><-married_to-', '-born_to->'] => 1.0,

      ['-born_to-><-married_to-', '-step_child_of->'] => 0.0, # ?

      # Cousin
      ['-cousin_of->', '-born_to-><-niece_nephew_of-'] => 0.0, # ?

      # Child in Law
      ['-child_in_law_of->', '-married_to->-born_to->'] => 0.0, # ?
    }

    # Generating a Hash that looks like this for performance:
    # {
    #   '<-married_to-' => {'-married_to->' => 1.0},
    #   '-married_to->' => {'<-married_to-' => 1.0},
    # }
    RELATION_EQUIVILENCE_SCORES = RELATION_EQUIVILENCE_SCORES_BASE.each_with_object({}) do |(paths, score), hash|
      path1, path2 = paths

      hash[path1] ||= {}
      hash[path1][path2] = score

      hash[path2] ||= {}
      hash[path2][path1] = score
    end


    def field_scorers
      {
        forename: :fuzzy_string,
        surname: :fuzzy_string,
        religion: :exact_string,
        age: proc do |age1, age2, options = {}|
          if age1.present? && age2.present?
            age_difference = (age1 - age2).abs - 10

            RecordLinkage::Matchers.call_matcher(:number_nearness,
                                                 age_difference,
                                                 0.0,
                                                 options)
          end || 0.0
        end,
        sex: :exact_string,
        # relations: proc do |relations1, relations2, options = {}|
        #   resident1 = options[:object1]
        #   resident2 = options[:object2]
        # 
        #   relations1.map do |relation1|
        #     relations2.map do |relation2|
        #       if relation1.resident == relation2.resident
        #         require 'pry'
        #         binding.pry
        #         if relation1.path == relation2.path
        #           1.0
        #         else
        #           (RELATION_EQUIVILENCE_SCORES[relation1.path] || {})[relation2.path] || 0.0
        #         end
        #       end || 0.0
        #     end
        #   end.flatten.max || 0.0
        # end

        #latitude: :number_nearness,
        #longitude: :number_nearness,
        #ded_name: :fuzzy_string,
        #townland_street_name: :fuzzy_string
      }
    end

    def field_options
      {
        forename: {weight: 10},
        surname: {weight: 4},
        religion: {weight: 5},
        age: {weight: 10, max: 5},
        sex: {weight: 10},
        # relations: {weight: 5}
        # latitude: {weight: 5},
        # longitude: {weight: 5},
        # ded_name: {weight: 5},
        # townland_street_name: {weight: 5}
      }
    end
  end

  #private

  #def census_year
  #  @census_year ||= residence.census_year
  #end

  def other_census_year
    case census_year
    when 1901
      1911
    when 1911
      1901
    else
      raise "Invalid census year: #{census_year.inspect}"
    end
  end

  def age_in(year)
    return nil if not age

    years_different = census_year - year

    age - years_different
  end
end
