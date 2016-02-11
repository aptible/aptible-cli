require 'spec_helper'

describe Aptible::CLI::Helpers::App::HandleFromGitRemote do
  it 'should parse handle from remote without account' do
    str = 'git@test.aptible.com:test-app.git'
    result = described_class.parse(str)[:app_handle]
    expect(result).not_to be nil
    expect(result).to eql 'test-app'
  end

  it 'should parse handle from remote with account' do
    str = 'git@test.aptible.com:test-account/test-app.git'
    result = described_class.parse(str)[:app_handle]
    expect(result).not_to be nil
    expect(result).to eql 'test-app'
  end
end
