class IrishCensus::CountiesController < IrishCensus::GeoObjectsController
  def index
    @counties = Neo::County.all
  end

  def geo_object_class
    Neo::County
  end
end

