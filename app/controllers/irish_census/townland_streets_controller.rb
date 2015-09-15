class IrishCensus::TownlandStreetsController < IrishCensus::GeoObjectsController
  def show
    townland_street = get_geo_object

    @title = "#{townland_street.name}"

    super
  end

  def geo_object_class
    Neo::TownlandStreet
  end
end
