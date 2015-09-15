module ApplicationHelper
  def irish_census_link(text, house, html_options = {})
    census_year = house.census_year
    townland_street = house.townland_street.name
    ded = house.townland_street.ded.name
    county = house.townland_street.ded.county.name
    census_id = house.census_id
    link_to text, "http://www.census.nationalarchives.ie/pages/#{census_year}/#{county}/#{ded}/#{townland_street}/#{census_id}/", html_options
  end

  def irish_graveyards_link(text = 'Irish Graveyards', options = {})
    invalid_keys = options.keys.map(&:to_s) - %w{firstname lastname address month year}
    raise ArgumentError, "Invalid keys: #{invalid_keys.to_sentence}" if invalid_keys.present?

    options[:lastname] = options[:lastname].gsub("'", '')
    link_to text, 'http://www.irishgraveyards.ie/search.php?yardid=0&area_id=0&' + options.to_param
  end

end
