class IrishCensus::GeoObjectsController < ApplicationController
  def show
    @geo_object = get_geo_object
    render 'irish_census/geo_objects/show'
  end

  private

  def get_geo_objects
    geo_object_class.limit(200)
  end

  def get_geo_object
    geo_object_class.find(params[:id])
  end
end

