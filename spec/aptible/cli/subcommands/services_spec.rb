require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { double 'token' }
  let(:app) { Fabricate(:app) }

  before do
    allow(subject).to receive(:fetch_token) { token }
    allow(Aptible::Api::App).to receive(:all).with(token: token)
      .and_return([app])
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

    expect(captured_output_text.split("\n")).to include('Container Size: 1024')
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
