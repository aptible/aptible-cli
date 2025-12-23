require 'spec_helper'

describe Aptible::CLI::Helpers::Token do
  around do |example|
    Dir.mktmpdir { |home| ClimateControl.modify(HOME: home) { example.run } }
  end

  subject { Class.new.send(:include, described_class).new }

  let(:token) { 'test-token' }
  let(:user) { double('user', id: 'user-id', email: 'test@example.com') }
  let(:auth_token) { double('auth_token', user: user) }

  describe '#save_token / #fetch_token' do
    it 'reads back a token it saved' do
      subject.save_token('foo')
      expect(subject.fetch_token).to eq('foo')
    end
  end

  context 'permissions' do
    before { skip 'Windows' if Gem.win_platform? }

    describe '#save_token' do
      it 'creates the token_file with mode 600' do
        subject.save_token('foo')
        expect(format('%o', File.stat(subject.token_file).mode))
          .to eq('100600')
      end
    end

    describe '#current_token_hash' do
      it 'updates the token_file to mode 600' do
        subject.save_token('foo')
        File.chmod(0o644, subject.token_file)
        expect(format('%o', File.stat(subject.token_file).mode))
          .to eq('100644')

        subject.current_token_hash
        expect(format('%o', File.stat(subject.token_file).mode))
          .to eq('100600')
      end
    end
  end

  describe '#current_token' do
    before do
      subject.save_token(token)
    end

    it 'returns the current auth token' do
      expect(Aptible::Auth::Token).to receive(:current_token)
        .with(token: token)
        .and_return(auth_token)

      expect(subject.current_token).to eq(auth_token)
    end

    it 'raises Thor::Error on 401 unauthorized' do
      response = Faraday::Response.new(status: 401)
      error = HyperResource::ClientError.new('401 (invalid_token) Invalid Token',
                                             response: response)
      expect(Aptible::Auth::Token).to receive(:current_token)
        .with(token: token)
        .and_raise(error)

      expect { subject.current_token }
        .to raise_error(Thor::Error, /Invalid Token/)
    end

    it 'raises Thor::Error on 403 forbidden' do
      response = Faraday::Response.new(status: 403)
      error = HyperResource::ClientError.new('403 (forbidden) Access denied',
                                             response: response)
      expect(Aptible::Auth::Token).to receive(:current_token)
        .with(token: token)
        .and_raise(error)

      expect { subject.current_token }
        .to raise_error(Thor::Error, /Access denied/)
    end
  end

  describe '#whoami' do
    before do
      subject.save_token(token)
    end

    it 'returns the current user' do
      expect(Aptible::Auth::Token).to receive(:current_token)
        .with(token: token)
        .and_return(auth_token)

      expect(subject.whoami).to eq(user)
    end

    it 'raises Thor::Error on API error' do
      response = Faraday::Response.new(status: 401)
      error = HyperResource::ClientError.new('401 (invalid_token) Invalid Token',
                                             response: response)
      expect(Aptible::Auth::Token).to receive(:current_token)
        .with(token: token)
        .and_raise(error)

      expect { subject.whoami }
        .to raise_error(Thor::Error, /Invalid Token/)
    end
  end
end
