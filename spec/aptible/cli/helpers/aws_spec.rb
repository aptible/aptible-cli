require 'spec_helper'

describe Aptible::CLI::Helpers::AwsHelpers do

  subject { Class.new.send(:include, described_class).new }

  let(:v2app) { 'mystack/shareable/v2/fakesha/apps-321/fakebread-json.log.2022-06-29T18:30:01.bck.gz' }
  let(:v3app) { 'mystack/shareable/v3/fakesha/apps-321/service-123/fakebread-json.log.2022-06-29T18:30:01.bck.gz}
  describe '#info_from_path' do
  it 'can read data from v2 paths' do     
    result = subject.info_from_path(v2app)  
    expect(result[:schema]).to eq('v2')
    expect(result[:shasum]).to eq('fakesha')
    expect(result[:type]).to eq('apps')
    expect(result[:id]).to eq(321)
    expect(result[:container_id]).to eq('fakebread')
    expect(result[:uploaded_at]).to eq('2022-06-29T18:30:01')
  end

  it 'can read data from v3 paths' do     
    result = subject.info_from_path(v2app)  
    expect(result[:schema]).to eq('v2')
    expect(result[:shasum]).to eq('fakesha')
    expect(result[:type]).to eq('apps')
    expect(result[:id]).to eq(321)
    expect(result[:service_id]).to eq(123)
    expect(result[:container_id]).to eq('fakebread')
    expect(result[:uploaded_at]).to eq('2022-06-29T18:30:01')
  end
  end
end