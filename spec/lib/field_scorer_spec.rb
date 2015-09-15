require 'spec_helper'
require 'field_scorer'

describe ObjectScoring::ObjectScorer do
  let(:object_class) { Struct.new(:name, :age) }
  let(:object1) do
    object_class.new('Jim', 15)
  end

  let(:field_scorers) { {} }

  let(:field_weights) { {} }

  let(:scorer) do
    ObjectScoring::ObjectScorer.new(object1, field_scorers, field_weights)
  end

  describe '#percentage_score' do
    subject { scorer.percentage_score(object_class.new(name, age)) }

    context 'scoring name exactly' do
      let(:field_scorers) { {name: :exact} }

      context 'perfect name match' do
        let(:name) { 'Jim' }

        context 'perfect age match' do
          let(:age) { 15 }
          it { should == 1.0 }
        end

        context 'imperfect age match' do
          let(:age) { 14 }
          it { should == 1.0 }
        end
      end

      context 'imperfect name match' do
        let(:name) { 'jim' }

        context 'perfect age match' do
          let(:age) { 15 }
          it { should == 0.0 }
        end

        context 'imperfect age match' do
          let(:age) { 14 }
          it { should == 0.0 }
        end
      end
    end

    context 'scoring name and age exactly' do
      let(:field_scorers) { {name: :exact, age: :exact} }

      context 'perfect name match' do
        let(:name) { 'Jim' }

        context 'perfect age match' do
          let(:age) { 15 }
          it { should == 1.0 }
        end

        context 'imperfect age match' do
          let(:age) { 14 }
          it { should == 0.5 }
        end
      end

      context 'imperfect name match' do
        let(:name) { 'jim' }

        context 'perfect age match' do
          let(:age) { 15 }
          it { should == 0.5 }
        end

        context 'imperfect age match' do
          let(:age) { 14 }
          it { should == 0.0 }
        end
      end
    end
  end
end

