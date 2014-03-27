require 'spec_helper'

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }

  describe '#version' do
    it 'should print the version' do
      version = Aptible::CLI::VERSION
      expect(STDOUT).to receive(:puts).with "aptible-cli v#{version}"
      subject.version
    end
  end

  describe '#login' do
    let(:token) { double('Aptible::Auth::Token') }

    before { OAuth2::Error.send :define_method, :initialize, -> {} }
    before { token.stub(:access_token) { 'access_token' } }

    it 'should save a token to ~/.aptible/tokens' do
      Aptible::Auth::Token.stub(:create) { token }
      expect(subject).to receive(:save_token).with('access_token')
      subject.login
    end

    it 'should raise an error if authentication fails' do
      Aptible::Auth::Token.stub(:create).and_raise OAuth2::Error
      expect do
        subject.login
      end.to raise_error 'Could not authenticate with given credentials'
    end
  end
end
