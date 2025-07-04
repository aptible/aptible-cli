require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { double 'token' }
  let(:app) { Fabricate(:app) }

  before do
    allow(subject).to receive(:fetch_token) { token }
    allow(Aptible::Api::App)
      .to receive(:all)
      .with(token: token, href: '/apps?per_page=5000&no_embed=true')
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

    it 'lists container profile' do
      Fabricate(:service, app: app, instance_class: 'u7')
      subject.send('services')

      expect(captured_output_text.split("\n"))
        .to include('Container Profile: u')
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

    it 'allows setting stop timeout' do
      stub_options(stop_timeout: 30)
      service = Fabricate(:service, app: app, process_type: 'foo')

      expect(service).to receive(:update!).with(stop_timeout: 30)

      subject.send('services:settings', 'foo')
    end

    it 'allows setting stop timeout with other options' do
      stub_options(stop_timeout: 30, force_zero_downtime: true)
      service = Fabricate(:service, app: app, process_type: 'foo')

      expect(service).to receive(:update!)
        .with(stop_timeout: 30, force_zero_downtime: true)

      subject.send('services:settings', 'foo')
    end
  end

  describe '#services:sizing_policy' do
    let(:base_options) { { app: app.handle } }

    it 'returns the sizing policy' do
      stub_options
      service = Fabricate(:service, app: app, process_type: 'foo')
      sizing_policy = Fabricate(:service_sizing_policy)
      expect(service).to receive(:service_sizing_policy)
        .and_return(sizing_policy)

      subject.send('services:sizing_policy', 'foo')

      out = captured_output_text
      expect(out).to match(/Autoscaling Type: vertical/i)
      expect(out).to match(/Metric Lookback Seconds: 1800/i)
      expect(out).to match(/Percentile: 99.0/i)
      expect(out).to match(/Post Scale Up Cooldown Seconds: 60/i)
      expect(out).to match(/Post Scale Down Cooldown Seconds: 300/i)
      expect(out).to match(/Post Release Cooldown Seconds: 300/i)
      expect(out).to match(/Mem Cpu Ratio R Threshold: 4/i)
      expect(out).to match(/Mem Cpu Ratio C Threshold: 2/i)
      expect(out).to match(/Mem Scale Up Threshold: 0.9/i)
      expect(out).to match(/Mem Scale Down Threshold: 0.75/i)
      expect(out).to match(/Minimum Memory: 2048/i)
      expect(out).to match(/Maximum Memory:/i)
      expect(out).to match(/Min Cpu Threshold: 0.4/i)
      expect(out).to match(/Max Cpu Threshold: 0.9/i)
      expect(out).to match(/Min Containers: 2/i)
      expect(out).to match(/Max Containers: 5/i)
      expect(out).to match(/Scale Up Step: 1/i)
      expect(out).to match(/Scale Down Step: 1/i)
    end

    it 'raises an error if the environment has no policy' do
      stub_options
      service = Fabricate(:service, app: app, process_type: 'foo')
      expect(service).to receive(:service_sizing_policy).and_return(nil)
      expect { subject.send('services:sizing_policy', 'foo') }
        .to raise_error(/does not have a service sizing policy set/)
    end

    it 'is aliased to autoscaling_policy' do
      stub_options
      service = Fabricate(:service, app: app, process_type: 'foo')
      sizing_policy = Fabricate(:service_sizing_policy)
      expect(service).to receive(:service_sizing_policy)
        .and_return(sizing_policy)

      subject.send('services:autoscaling_policy', 'foo')

      out = captured_output_text
      expect(out).to match(/Autoscaling Type: vertical/i)
    end
  end

  describe '#services:sizing_policy:set' do
    let(:base_options) { { app: app.handle } }
    let(:args) do
      {
        autoscaling_type: 'vertical',
        mem_scale_down_threshold: 0.5,
        scale_up_step: 2,
        post_scale_down_cooldown_seconds: 3,
        percentile: 93.2
      }
    end

    it 'raises an error if the autoscaling type is invalid' do
      stub_options(autoscaling_type: 'invalid')
      Fabricate(:service, app: app, process_type: 'foo')
      expect { subject.send('services:sizing_policy:set', 'foo') }
        .to raise_error(/Invalid autoscaling type: invalid/)
    end

    it 'raises an error if the autoscaling type is horizontal '\
       'and min_containers is not set' do
      stub_options(autoscaling_type: 'horizontal', min_containers: nil)
      Fabricate(:service, app: app, process_type: 'foo')
      expect { subject.send('services:sizing_policy:set', 'foo') }
        .to raise_error(
          /min_containers and max_containers are required for horizontal autos/
        )
    end

    it 'updates existing sizing policy' do
      stub_options(**args)
      service = Fabricate(:service, app: app, process_type: 'foo')
      sizing_policy = double(sizing_policy)
      expect(service).to receive(:service_sizing_policy)
        .and_return(sizing_policy)

      api_args = args.except(:autoscaling_type)
      api_args[:autoscaling] = args[:autoscaling_type]

      expect(sizing_policy).to receive(:update!)
        .with(**api_args.update(service_id: service.id))

      subject.send('services:sizing_policy:set', 'foo')
    end

    it 'creates a new sizing policy if necessary' do
      stub_options(**args)
      service = Fabricate(:service, app: app, process_type: 'foo')

      api_args = args.except(:autoscaling_type)
      api_args[:autoscaling] = args[:autoscaling_type]

      expect(service).to receive(:create_service_sizing_policy!)
        .with(**api_args)

      subject.send('services:sizing_policy:set', 'foo')
    end

    it 'is aliased to autoscaling_policy:set' do
      stub_options(**args)
      service = Fabricate(:service, app: app, process_type: 'foo')

      api_args = args.except(:autoscaling_type)
      api_args[:autoscaling] = args[:autoscaling_type]

      expect(service).to receive(:create_service_sizing_policy!)
        .with(**api_args)

      subject.send('services:autoscaling_policy:set', 'foo')
    end
  end

  def stub_options(**opts)
    allow(subject).to receive(:options).and_return(base_options.merge(opts))
  end
end
