require 'spec_helper'

describe Aptible::CLI::Helpers::Database do
  subject { Class.new.send(:include, described_class).new }

  describe '#validate_image_type' do
    let(:pg) do
      Fabricate(:database_image, type: 'postgresql', version: '10')
    end

    let(:redis) do
      Fabricate(:database_image, type: 'redis', version: '9.4')
    end

    let(:token) { 'some-token' }

    before do
      allow(subject).to receive(:fetch_token).and_return(token)
      allow(Aptible::Api::DatabaseImage).to receive(:all)
        .and_return([pg, redis])
    end

    it 'Raises an error if provided an invalid type' do
      bad_type = 'cassandra'
      err = "No Database Image of type \"#{bad_type}\", " \
            "valid types: #{pg.type}, #{redis.type}"
      expect do
        subject.validate_image_type(bad_type)
      end.to raise_error(Thor::Error, err)
    end

    it 'Retruns true when provided a valid type' do
      expect(subject.validate_image_type(pg.type)).to be(true)
    end
  end
end
