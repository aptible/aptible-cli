require 'spec_helper'

describe Aptible::CLI::Helpers::DateHelpers do
  subject { Class.new.send(:include, described_class).new }

  describe '#utc_string' do
    it 'should accept a Datetime string from our API and return a UTC string' do
      result = subject.utc_string('2023-09-05T22:00:00.000Z')
      expect(result).to eq '2023-09-05 22:00:00 UTC'
    end
  end
end
