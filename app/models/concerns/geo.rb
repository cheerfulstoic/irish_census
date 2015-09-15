module Geo
  extend ActiveSupport::Concern

  def google_geocode_result
    Geocoder.search(geocode_string).select do |result|
      respond_to?(:geo_parent) ? viewport_contains(geo_parent.google_geocode_result, result) : true
    end[0]
  end

  def viewport_contains(viewport_result, result)
    return false if not viewport_result

    viewport_data = viewport_result.data['geometry']['viewport']

    lats = [viewport_data['northeast']['lat'], viewport_data['southwest']['lat']].sort
    longs = [viewport_data['northeast']['lng'], viewport_data['southwest']['lng']].sort

    (lats[0]..lats[1]).include?(result.latitude) &&
      (longs[0]..longs[1]).include?(result.longitude)
  end

  def ancestors
    if geo_parent
      geo_parent.ancestors + [geo_parent]
    else
      []
    end
  end
end
