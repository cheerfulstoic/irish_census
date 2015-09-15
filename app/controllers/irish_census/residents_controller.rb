class IrishCensus::ResidentsController < ApplicationController
  def show
    @resident = Neo::Resident.find(params[:id])
  end

  def identify
    return render text: 'ERROR' if params[:source_id].blank? || params[:target_id].blank?

    source = Neo::Resident.find(params[:source_id])
    target = Neo::Resident.find(params[:target_id])

    case params[:type]
    when 'same'
      source.identify_as(target)
    when 'different'
      source.identify_as_not(target)
    when 'clear'
      source.clear_identified_as
    else
      raise "Invalid type param"
    end

    source = Neo::Resident.find(params[:source_id])
    render json: {same_identity: source.identified_as?(target)}
  end
end
