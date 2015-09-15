require 'rails_helper'

describe Ar::Resident do
  let(:resident) { Ar::Resident.create(resident_attributes) }

  describe '.age_candidates' do
    context 'same age' do
      let(:resident_attributes) { {age: 22} }

      it { Ar::Resident.age_candidates(22).should include(resident) }
    end
  end
end
