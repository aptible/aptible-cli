require 'spec_helper'

describe Aptible::CLI::Agent do
  before do
    allow(subject).to receive(:ask)
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:fetch_token) { double 'token' }
  end

  let!(:account) { Fabricate(:account) }
  let!(:app) { Fabricate(:app, handle: 'hello', account: account) }
  let!(:service) { Fabricate(:service, app: app) }
  let(:op) { Fabricate(:operation, status: 'succeeded', resource: app) }

  before do
    allow(Aptible::Api::App).to receive(:all) { [app] }
    allow(Aptible::Api::Account).to receive(:all) { [account] }
  end

  let!(:vhost1) do
    Fabricate(:vhost, virtual_domain: 'domain1', external_host: 'host1',
                      service: service)
  end

  let!(:vhost2) do
    Fabricate(:vhost, virtual_domain: 'domain2', external_host: 'host2',
                      service: service)
  end

  describe '#domains' do
    it 'should print out the hostnames' do
      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return([app])
      allow(subject).to receive(:options) do
        { environment: 'foobar', app: 'web' }
      end
      expect(subject).to receive(:say).with('domain1')
      expect(subject).to receive(:say).with('domain2')

      subject.send('domains')
    end

    it 'should fail if app is non-existent' do
      allow(subject).to receive(:options) { { app: 'not-an-app' } }

      expect do
        subject.send('domains')
      end.to raise_error(Thor::Error, /Could not find app/)
    end

    it 'should fail if environment is non-existent' do
      allow(Aptible::Api::Account).to receive(:all) { [] }

      expect do
        subject.send('domains')
      end.to raise_error(Thor::Error)
    end

    it 'should print hostnames if -v is passed' do
      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return([app])
      allow(subject).to receive(:options) do
        { verbose: true, app: 'hello', environment: 'foobar' }
      end

      expect(subject).to receive(:say).with('domain1 -> host1')
      expect(subject).to receive(:say).with('domain2 -> host2')

      subject.send('domains')
    end
  end
end
