class IrishCensus::HousesController < ApplicationController
  def show
    @house = get_house

    @title = "##{@house.house_number} - #{@house.census_year}"

    puts "request.referer", request.referer.inspect
  end

  def compare_candidate_houses
    @house = get_house
    @candidate_houses = @house.similar_houses
  end

  def compare
    @house1 = Neo::House.find(params[:census_id_1])
    @house2 = Neo::House.find(params[:census_id_2])
  end

  private

  def get_house
    if params[:census_id]
      Neo::House.where(census_id: params[:census_id].to_i).first
    else
      Neo::House.find(params[:id])
    end
  end
end
