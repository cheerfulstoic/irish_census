module Neo
  class DED
    include Neo4j::ActiveNode
    include Geo
    set_mapped_label_name 'DED'

    property :name

    has_one :out, :county, type: 'IN', model_class: 'Neo::County'
    has_many :in, :townland_streets, type: 'IN', model_class: 'Neo::TownlandStreet'

    searchkick

    include Comparable

    def self.residents(*args)
      all.townland_streets.houses.residents(*args)
    end

    def residents(*args)
      townland_streets.houses.residents(*args)
    end

    def <=>(other)
      name <=> other.name
    end

    def geocode_string
      "#{name}, #{county.geocode_string}"
    end

    def geo_parent
      county
    end

    def geo_children
      townland_streets
    end
  end
end
