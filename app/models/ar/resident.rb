module Ar
  class Resident < ActiveRecord::Base
    self.primary_key = :uuid
    self.table_name = 'residents'

    include ResidentCommon

    searchkick index_name: 'resident_shared',
               batch_size: 4_000,
               word_start: [:forename, :surname], 
               word_middle: [:forename, :surname], 
               word_end: [:forename, :surname]

    def to_partial_path
      'residents/resident'
    end

    def neo_record
#      Neo::Resident.where(id: uuid).first
    end

    def residence
      neo_record.residence
    end
    
    scope :age_candidates, (Proc.new do |age|
      if age
        self.where("age BETWEEN ? AND ? OR age IS NULL", age - AGE_SIMILARITY_DELTA, age + AGE_SIMILARITY_DELTA)
      else
        self.all
      end
    end)

  end
end

