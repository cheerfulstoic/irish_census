module Neo
  class TownlandStreet
    include Neo4j::ActiveNode
    include Geo

    set_mapped_label_name 'TownlandStreet'

    property :name
    property :latitude, type: Float
    property :longitude, type: Float

    has_one :out, :ded, type: 'IN', model_class: 'Neo::DED'
    has_many :in, :houses, type: 'IN', model_class: 'Neo::House'

    searchkick batch_size: 3_000

    include Comparable

    def <=>(other)
      name <=> other.name
    end

    def geocode_string
      "#{name}, #{ded.county.geocode_string}"
    end

    def geo_parent
      ded
    end

    def geo_children
      houses
    end
  end
end
