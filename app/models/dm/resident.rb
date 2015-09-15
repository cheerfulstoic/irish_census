class DM::Resident
  include DataMapper::Resource
  include ResidentCommon

  storage_names[:default] = 'residents'

  property :uuid, String, key: true, length: 24
  property :census_year, Integer, index: true
  property :census_id, Integer, index: true
  property :surname, String, index: true, length: 78
  property :forename, String, index: true, length: 73
  property :age, Integer, index: true
  property :sex, String, index: true, length: 6
  property :relation_to_head, String, index: true, length: 114
  property :religion, String, index: true, length: 193
  property :birthplace, String, index: true, length: 75
  property :occupation, String, index: true, length: 255
  property :literacy, String, index: true, length: 61
  property :irish_language, String, index: true, length: 69
  property :marital_status, String, index: true, length: 20
  property :specified_illness, String, index: true, length: 89
  property :years_married, Integer, index: true
  property :children_born, Integer, index: true
  property :children_living, Integer, index: true

  def neo_record
    Neo::Resident.where(id: uuid).first
  end

  def residence
    neo_record.residence
  end

end
