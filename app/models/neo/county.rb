module Neo
  class County
    include Neo4j::ActiveNode
    include Geo
    set_mapped_label_name 'County'

    # stack level too deep when just: id_property :uuid

    property :name
    property :latitude, type: Float
    property :longitude, type: Float

    has_many :in, :deds, model_class: 'Neo::DED', origin: :county

    searchkick text_start: [:name]

    def search_data
      {name: name}
    end

    def self.search_name(input)
      County.search(input, fields: [{name: :word_start}, case_sensitive: false])
    end

    def geocode_string
      "County #{name}, Ireland"
    end

    def geo_parent
      nil
    end

    def geo_children
      deds
    end
  end
end
