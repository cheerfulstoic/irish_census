class Neo::Resident
  include Neo4j::ActiveNode
  include ResidentCommon

  set_mapped_label_name 'Resident'

  def to_partial_path
    'residents/resident'
  end

  searchkick index_name: 'resident_neo_shared',
             batch_size: 4_000,
             word_start: [:forename, :surname],
             word_middle: [:forename, :surname],
             word_end: [:forename, :surname]

  #id_property :id, auto: :uuid

  property :forename
  property :surname
  property :age, type: Integer
  property :sex
  property :relation_to_head
  property :religion
  property :birthplace
  property :occupation
  property :literacy
  property :irish_language
  property :marital_status
  property :specified_illness
  property :years_married
  property :children_born
  property :children_living
  property :census_year # Copied from House

  has_one :out, :residence, type: 'LIVES_IN', model_class: 'Neo::House'

  has_one :both, :identified_as, type: 'IDENTIFIED_AS', model_class: 'Neo::Resident'
  #has_many :both, :identified_as_not, type: 'identified_as_not', model_class: 'Neo::Resident'

  has_many :out, :similarity_candidates_rel, type: :similarity_candidate, model_class: 'Neo::Resident'

  # THIS SHOULD WORK!!  !
  #has_many :both, :family, type: [:married_to, :born_to], model_class: 'Neo::Resident'

  #def self.search(*args)
  #  where(id: Ar::Resident.search(*args).map(&:id))
  #end

  Relation = Struct.new(:resident, :relationship_path)

  RELATIONS_RELATIONSHIP_TYPES = %w(
    born_to
    married_to
    grandchild_of
    niece_nephew_of
    sibling_of
    cousin_of
    child_in_law_of
    step_child_of
  )

  def relation_string_from_path_and_rels(path, rels)
    rels.each_with_index.map do |rel, i|
      dir = path[:directions][i]

      dir[0].gsub('<', '<-') + rel.rel_type.to_s + dir[1].gsub('>', '->')
    end.join
  end

  def relations
    @relations ||= query_as(:r).
      match("path=r-[rel:#{RELATIONS_RELATIONSHIP_TYPES.join('|')}*1..2]-r2").
      pluck(:r2, :path, 'rels(path)').map do |r2, path, rels|
        Relation.new(r2, relation_string_from_path_and_rels(path, rels))
    end
  end

  def similarity_hash_to(candidate)
    self.class.object_comparer.classify_hash(self, candidate).each_with_object({}) do |(props, score), hash|
      hash[props[0]] = score
    end
  end

  attr_accessor :relationships_score

  def refresh_similarity_candidate_rels
    self.similarity_candidates_rel = []

    similarity_candidates.each do |candidate|
      hash = similarity_hash_to(candidate)
      self.similarity_candidates_rel.create(candidate, hash.merge(total: hash.values.sum))
    end
  end

  RELATIONSHIPS_SCORE_WEIGHT = 8
  def add_relationships_similarity_candidate_scores
    get_similarity_candidate_relationship_paths.each do |candidate, score|
      self.similarity_candidates_rel(nil, :rel)
        .where(id: candidate.id)
        .query
        .set(rel: {relationships_score: score * RELATIONSHIPS_SCORE_WEIGHT})
        .set('rel.total = rel.total + {score}')
        .params(score: score)
        .exec
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
    ['-child_in_law_of->', '-married_to->-born_to->'] => 0.0, # ,
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



  def get_similarity_candidate_relationship_paths
    self.query_as(:h1_r1)
      .match('(h1:House), (h2:House)')
      .match('h1<-[:LIVES_IN]-h1_r1-[sc_1:similarity_candidate]-(h2_r1)-[:LIVES_IN]->h2')
      .match('h1<-[:LIVES_IN]-h1_r2-[sc_2:similarity_candidate]-(h2_r2)-[:LIVES_IN]->h2')
      .match('path1=h1_r1-[:born_to|married_to|grandchild_of|niece_nephew_of|sibling_of|cousin_of|child_in_law_of|step_child_of*1..2]-h1_r2')
      .match('path2=h2_r1-[:born_to|married_to|grandchild_of|niece_nephew_of|sibling_of|cousin_of|child_in_law_of|step_child_of*1..2]-h2_r2')
      .pluck(
        :h2_r1,
        'collect([path1, rels(path1), path2, rels(path2)])'
        ).each_with_object({}) do |(r2, data), result|

      result[r2] = data.inject(0) do |total, (path1, rels1, path2, rels2)|
        relations1 = relation_string_from_path_and_rels(path1, rels1)
        relations2 = relation_string_from_path_and_rels(path2, rels2)

        if relations1 == relations2
          1.0
        elsif score = (RELATION_EQUIVILENCE_SCORES[relations1] || {})[relations2]
          score
        else
          -2.0
        end + total
      end
    end
  end


  # A way to eager-load random class methods?

  def identify_as(other_node)
    clear_identified_as
    self.identified_as = other_node
  end

  def identify_as_not(other_node)
    clear_identified_as
    self.identified_as_not << other_node
  end

  def identify_as_unidentified
    clear_identified_as
  end

  def clear_identity_with(other_node)
    self.query_as(:n).match("n-[r:identified_as|identified_as_not]-(other)").where(other: {id: other_node.id}).delete(:r).exec
  end

  def clear_identified_as
    self.query_as(:n).match("n-[r:identified_as|identified_as_not]-()").delete(:r).exec
  end

  def identified_as?(other_node)
    self.query_as(:n).match("n-[r:identified_as]-(other)").where(other: {id: other_node.id}).pluck("count(r)").first > 0
  end

  attr_writer :townland_street
  def townland_street
    @townland_street ||= residence.query_as(:house).match("house--(ts:TownlandStreet)").pluck(:ts).first
  end

  def townland_street_name
    townland_street.name
  end

  attr_writer :ded
  def ded
    @ded ||= townland_street.ded
  end

  def ded_name
    ded.name
  end

  def reindex(options = {})
    searchkick_index.reindex_scope(all, options)
  end

  #def self.reindex
  #  Ar::Resident.where(uuid: pluck_current(:id)).reindex
  #end
end
