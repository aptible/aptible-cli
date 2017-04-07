require 'spec_helper'

describe Aptible::CLI::Helpers::Tunnel do
  include_context 'mock ssh'

  it 'opens a tunnel' do
    helper = described_class.new({}, ['ssh'], '/some.sock')

    helper.start(0)
    helper.stop

    mock_argv = read_mock_argv
    expect(mock_argv.size).to eq(4)

    expect(mock_argv.shift).to eq('-L')
    expect(mock_argv.shift).to match(%r{\d+:/some\.sock$})
    expect(mock_argv.shift).to eq('-o')
    expect(mock_argv.shift).to eq('ExitOnForwardFailure=yes')
  end

  it 'accepts a desired local port' do
    helper = described_class.new({}, ['ssh'], '/some.sock')
    helper.start(5678)
    helper.stop

    mock_argv = read_mock_argv
    expect(mock_argv.size).to eq(4)

    expect(mock_argv.shift).to eq('-L')
    expect(mock_argv.shift).to eq('5678:/some.sock')
  end

  it 'provides the port it picked' do
    helper = described_class.new({}, ['ssh'], '/some.sock')
    helper.start
    port = helper.port
    helper.stop

    mock_argv = read_mock_argv
    expect(mock_argv.size).to eq(4)

    expect(mock_argv.shift).to eq('-L')
    expect(mock_argv.shift).to eq("#{port}:/some.sock")
  end

  it 'captures and displays tunnel errors' do
    helper = described_class.new({ 'SSH_MOCK_FAIL_TUNNEL' => '1' }, ['ssh'],
                                 '/some.sock')

    expect { helper.start(0) }
      .to raise_error(/Tunnel did not come up.*Something went wrong/m)
  end

  it 'should fail if #port is called before #start' do
    socat = described_class.new({}, [], '/some.sock')
    expect { socat.port }.to raise_error(/You must call #start/)
  end

  it 'should fail if #stop is called before #start' do
    socat = described_class.new({}, [], '/some.sock')
    expect { socat.stop }.to raise_error(/You must call #start/)
  end

  it 'understands an exit status of 0' do
    helper = described_class.new(
      { 'SSH_MOCK_EXITCODE' => '0' }, ['ssh'], '/some.sock'
    )
    helper.start
    helper.wait
  end

  it 'understands an exit status of 1' do
    helper = described_class.new(
      { 'SSH_MOCK_EXITCODE' => '1' }, ['ssh'], '/some.sock'
    )
    helper.start
    expect { helper.wait }.to raise_error(/tunnel crashed/im)
  end

  it 'understands an exit status of 124' do
    helper = described_class.new(
      { 'SSH_MOCK_EXITCODE' => '124' }, ['ssh'], '/some.sock'
    )
    helper.start
    expect { helper.wait }.to raise_error(/tunnel timed out/im)
  end
end
