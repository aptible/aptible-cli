require 'spec_helper'
require 'climate_control'

describe Aptible::CLI::Helpers::Tunnel do
  around do |example|
    mocks_path = File.expand_path('../../../../mock', __FILE__)
    path = "#{mocks_path}:#{ENV['PATH']}"
    ClimateControl.modify PATH: path do
      example.run
    end
  end

  it 'reuses the port it was given' do
    helper = described_class.new({}, ['ssh_mock.rb'])

    r, w = IO.pipe
    helper.start(0, w)
    helper.stop

    expect(r.readline.chomp).to eq('6')
    expect(r.readline.chomp).to eq('-L')
    expect(r.readline.chomp).to match(/\d+:localhost:1234$/)
    expect(r.readline.chomp).to eq('-o')
    expect(r.readline.chomp).to eq('SendEnv=TUNNEL_PORT')
    expect(r.readline.chomp).to eq('-o')
    expect(r.readline.chomp).to eq('SendEnv=TUNNEL_SIGNAL_OPEN')

    r.close
    w.close
  end

  it 'accepts a desired port' do
    helper = described_class.new({}, ['ssh_mock.rb'])
    r, w = IO.pipe
    helper.start(5678, w)
    helper.stop

    expect(r.readline.chomp).to eq('6')
    expect(r.readline.chomp).to eq('-L')
    expect(r.readline.chomp).to eq('5678:localhost:1234')
    expect(r.readline.chomp).to eq('-o')
    expect(r.readline.chomp).to eq('SendEnv=TUNNEL_PORT')
    expect(r.readline.chomp).to eq('-o')
    expect(r.readline.chomp).to eq('SendEnv=TUNNEL_SIGNAL_OPEN')

    r.close
    w.close
  end

  it 'captures and displays port discovery errors' do
    helper = described_class.new({ 'FAIL_PORT' => '1' }, ['ssh_mock.rb'])
    expect { helper.start }.to raise_error(/Something went wrong/)
  end

  it 'captures and displays tunnel errors' do
    helper = described_class.new({ 'FAIL_TUNNEL' => '1' }, ['ssh_mock.rb'])
    expect do
      helper.start(0, File.open(File::NULL, 'w'))
    end.to raise_error(/Server closed the tunnel/)
  end

  it 'should fail if #port is called before #start' do
    socat = described_class.new({}, [])
    expect { socat.port }.to raise_error(/You must call #start/)
  end

  it 'should fail if #stop is called before #start' do
    socat = described_class.new({}, [])
    expect { socat.stop }.to raise_error(/You must call #start/)
  end
end
