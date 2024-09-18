require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { double 'token' }
  let(:app) { Fabricate(:app) }

  before do
    allow(subject).to receive(:fetch_token) { token }
    allow(Aptible::Api::App).to receive(:all).with(token: token)
      .and_return([app])
  end

  describe '#services' do
    before do
      allow(subject).to receive(:options).and_return(app: app.handle)
    end

    it 'lists a CMD service' do
      Fabricate(:service, app: app, process_type: 'cmd', command: nil)
      subject.send('services')

      expect(captured_output_text.split("\n")).to include('Service: cmd')
      expect(captured_output_text.split("\n")).to include('Command: CMD')
    end

    it 'lists a service with command' do
      Fabricate(:service, app: app, process_type: 'cmd', command: 'foobar')
      subject.send('services')

      expect(captured_output_text.split("\n")).to include('Service: cmd')
      expect(captured_output_text.split("\n")).to include('Command: foobar')
    end

    it 'lists container size' do
      Fabricate(:service, app: app, container_memory_limit_mb: 1024)
      subject.send('services')

      expect(captured_output_text.split("\n"))
        .to include('Container Size: 1024')
    end

    it 'lists container count' do
      Fabricate(:service, app: app, container_count: 3)
      subject.send('services')

      expect(captured_output_text.split("\n")).to include('Container Count: 3')
    end

    it 'lists multiple services' do
      Fabricate(:service, app: app, process_type: 'foo')
      Fabricate(:service, app: app, process_type: 'bar')
      subject.send('services')

      expect(captured_output_text.split("\n")).to include('Service: foo')
      expect(captured_output_text.split("\n")).to include('Service: bar')
    end
  end

  describe '#services:settings' do
    let(:base_options) { { app: app.handle } }

    it 'allows changing zero_downtime_deployment settings' do
      stub_options(force_zero_downtime: true, simple_health_check: true)
      service = Fabricate(:service, app: app, process_type: 'foo')

      expect(service).to receive(:update!)
        .with(force_zero_downtime: true, naive_health_check: true)

      subject.send('services:settings', 'foo')
    end

    it 'allows changing only one of the options' do
      stub_options(simple_health_check: true)
      service = Fabricate(:service, app: app, process_type: 'foo')

      expect(service).to receive(:update!).with(naive_health_check: true)

      subject.send('services:settings', 'foo')
    end
  end

  def stub_options(**opts)
    allow(subject).to receive(:options).and_return(base_options.merge(opts))
  end
end
