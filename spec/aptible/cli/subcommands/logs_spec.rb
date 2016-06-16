require 'spec_helper'

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }

  let!(:app) { Fabricate(:app, handle: 'foobar') }
  let!(:service) { Fabricate(:service, app: app) }

  describe '#logs' do
    before { allow(Aptible::Api::Account).to receive(:all) { [app.account] } }
    before { allow(Aptible::Api::App).to receive(:all) { [app] } }
    before { subject.options = { app: app.handle } }

    it 'should fail if the app is unprovisioned' do
      app.status = 'pending'
      expect { subject.send('logs') }
        .to raise_error(Thor::Error, /Have you deployed foobar yet/)
    end

    it 'should fail if the app has no services' do
      app.services = []
      expect { subject.send('logs') }
        .to raise_error(Thor::Error, /Have you deployed foobar yet/)
    end
  end
end
