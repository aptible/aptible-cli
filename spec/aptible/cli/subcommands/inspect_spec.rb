require 'spec_helper'

describe Aptible::CLI::Agent do
  describe '#inspect_resource' do
    let(:token) { 'foo token' }
    before { allow(subject).to receive(:fetch_token).and_return(token) }

    it 'should fail if the URI is invalid' do
      expect { subject.inspect_resource('^^') }
        .to raise_error(/invalid uri/im)
    end

    it 'should fail if the URI is not for a valid host' do
      expect { subject.inspect_resource('https://foo.com') }
        .to raise_error(/invalid api/im)
    end

    it 'should fail if the scheme is invalid' do
      # Not necessarily a feature per-se, but the URI will be parsed improperly
      # if we don't have a scheme.
      expect { subject.inspect_resource('api.aptible.com') }
        .to raise_error(/invalid scheme/im)
    end

    it 'should succeed if the URI is complete' do
      api = double('api')
      expect(Aptible::Api::Resource).to receive(:new).with(token: token)
        .and_return(api)

      res = double('resource', body: { foo: 'bar' })
      expect(api).to receive(:find_by_url).with('https://api.aptible.com/foo')
        .and_return(res)

      expect(subject).to receive(:puts) do |body|
        expect(JSON.parse(body)).to eq('foo' => 'bar')
      end

      subject.inspect_resource('https://api.aptible.com/foo')
    end
  end
end
