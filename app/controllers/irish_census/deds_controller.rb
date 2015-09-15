class IrishCensus::DedsController < IrishCensus::GeoObjectsController
  def show
    ded = get_geo_object

    @title = "#{ded.name}"

    @residents_by_townland_street_uuid = {}
    @identified_by_townland_street_uuid = {}


    # ded.townland_streets(:townland_street).
    #   houses.
    #   residents.query_as(:resident).
    #   optional_match('resident-[i:identified_as]-(:Resident)').
    Neo4j::Session.query.match(ded: {DED: {uuid: ded.uuid}}).
      match('ded<-[:IN]-(townland_street:TownlandStreet)<-[:IN]-(:House)<-[:LIVES_IN]-(resident:Resident)').
      optional_match('resident-[i:identified_as]-(other_resident:Resident)').

      pluck('townland_street.uuid, count(resident), count(i)').each do |townland_street_uuid, resident_count, identified_count|
        @residents_by_townland_street_uuid[townland_street_uuid] = resident_count
        @identified_by_townland_street_uuid[townland_street_uuid] = identified_count
      end

    super
  end

  def geo_object_class
    Neo::DED
  end
end

