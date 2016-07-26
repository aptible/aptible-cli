require 'spec_helper'

describe Aptible::CLI::Helpers::Tunnel do
  let(:ssh_mock_outfile) { Tempfile.new('tunnel_spec') }
  after do
    ssh_mock_outfile.close
    ssh_mock_outfile.unlink
  end

  def read_mock_argv
    File.open(ssh_mock_outfile) do |f|
      return JSON.load(f.read).fetch('argv')
    end
  end

  around do |example|
    mocks_path = File.expand_path('../../../../mock', __FILE__)
    env = {
      PATH: "#{mocks_path}:#{ENV['PATH']}",
      SSH_MOCK_OUTFILE: ssh_mock_outfile.path
    }
    ClimateControl.modify(env) { example.run }
  end

  it 'forwards traffic to the remote port given by the server (1234)' do
    helper = described_class.new({}, ['ssh_mock.rb'])

    helper.start(0)
    helper.stop

    mock_argv = read_mock_argv
    expect(mock_argv.size).to eq(8)

    expect(mock_argv.shift).to eq('-L')
    expect(mock_argv.shift).to match(/\d+:localhost:1234$/)
    expect(mock_argv.shift).to eq('-o')
    expect(mock_argv.shift).to eq('SendEnv=TUNNEL_PORT')
    expect(mock_argv.shift).to eq('-o')
    expect(mock_argv.shift).to eq('SendEnv=TUNNEL_SIGNAL_OPEN')
    expect(mock_argv.shift).to eq('-o')
    expect(mock_argv.shift).to eq('ExitOnForwardFailure=yes')
  end

  it 'accepts a desired local port' do
    helper = described_class.new({}, ['ssh_mock.rb'])
    helper.start(5678)
    helper.stop

    mock_argv = read_mock_argv
    expect(mock_argv.size).to eq(8)

    expect(mock_argv.shift).to eq('-L')
    expect(mock_argv.shift).to eq('5678:localhost:1234')
  end

  it 'captures and displays port discovery errors' do
    helper = described_class.new({ 'FAIL_PORT' => '1' }, ['ssh_mock.rb'])
    expect { helper.start }
      .to raise_error(/Failed to request.*Something went wrong/m)
  end

  it 'captures and displays tunnel errors' do
    helper = described_class.new({ 'FAIL_TUNNEL' => '1' }, ['ssh_mock.rb'])
    expect { helper.start(0) }
      .to raise_error(/Tunnel did not come up.*Something went wrong/m)
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
