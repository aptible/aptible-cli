require 'spec_helper'
require 'timeout'
require 'benchmark'

describe Aptible::CLI::Helpers::Socat do
  context 'without connections' do
    it 'should start and stop in a timely fashion' do
      socat = described_class.new({}, [])
      Timeout.timeout(5) do
        socat.start
        socat.stop
      end
    end

    it 'should fail if #port is called before #start' do
      socat = described_class.new({}, [])
      expect { socat.port }.to raise_error(/You must call #start/)
    end
  end

  context 'cleanup' do
    it 'should close all connections when exiting' do
      socat =  described_class.new({}, ['bash', '-c', 'echo "$$" && cat'])
      socat.start

      sock = Socket.tcp('127.0.0.1', socat.port)
      bash_pid = sock.recv(10).to_i

      `ps -p #{bash_pid}`.should include('bash')

      socat.stop

      # Test what we stopped listening for new connections
      expect { Socket.tcp('127.0.0.1', socat.port) }
        .to raise_error Errno::ECONNREFUSED

      # Test that bash exits when we close stdin
      Timeout.timeout(2) do
        sleep 0.1 while `ps -p #{bash_pid}`.include? 'bash'
      end
      `ps -p #{bash_pid}`.should_not include('bash')

      # Note: we can't reasonably test that the socket is closed, because that
      # takes a while
    end
  end

  context 'with socat' do
    let!(:socat) do
      described_class.new(socat_env, socat_cmd, File.open(File::NULL, 'w'))
    end
    let(:socat_env) { {} }
    let(:socat_cmd) { [] }

    around do |example|
      socat.start
      Timeout.timeout(5) do
        example.run
      end
      socat.stop
    end

    shared_examples 'do socat' do
      it 'should run a command when a connection is established' do
        Socket.tcp('127.0.0.1', socat.port) do |sock|
          expect(sock.read).to eq('hello')
        end
      end

      it 'should allow running multiple commands in parallel' do
        q = Queue.new

        threads = (1..10).map do
          Thread.new do
            Socket.tcp('127.0.0.1', socat.port) do |sock|
              q << sock.read
            end
          end
        end
        threads.each(&:join)

        expect(q.size). to eq(10)
        (1..10).each { expect(q.deq).to eq('hello') }
      end
    end

    context 'fast command' do
      let(:socat_cmd) { ['echo', '-n', 'hello'] }

      include_examples 'do socat'
    end

    context 'slow command' do
      let(:socat_cmd) { ['bash', '-c', 'sleep 2 && echo -n hello'] }

      include_examples 'do socat'
    end

    context 'with environment' do
      let(:socat_env) { { 'KEY' => 'VALUE' } }
      let(:socat_cmd) { ['bash', '-c', 'echo -n "$KEY"'] }

      it 'should passthrough the environment' do
        Socket.tcp('127.0.0.1', socat.port) do |sock|
          expect(sock.read).to eq('VALUE')
        end
      end
    end

    context 'overhead' do
      let(:socat_cmd) { ['dd', 'if=/dev/urandom', 'bs=8096', 'count=1024'] }

      it 'should transfer 8MB of data with less than 10% real overhead' do
        t_cmd, t_socat = Benchmark.bm do |b|
          b.report('bare') { Open3.capture3(*socat_cmd) }
          b.report('socat') do
            Socket.tcp('127.0.0.1', socat.port) do |sock|
              expect(sock.read.size).to eq(8290304)
            end
          end
        end

        expect(t_socat.real / t_cmd.real).to be <= 1.1
      end
    end
  end
end
