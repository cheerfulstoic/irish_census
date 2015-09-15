class IrishCensus::MainController < ApplicationController
  def redirect_from_census_website
    # http://www.census.nationalarchives.ie/pages/1901/Antrim/Aghagallon/Aghadrumglosney/1002268/
    puts "request.referer", request.referer
    _, _, census_year, county, ded, townland_street, census_id = URI(request.referer).path.split('/')

    redirect_to irish_census_house_by_census_id_path(census_id)
  end
end
