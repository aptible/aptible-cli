require 'spec_helper'

describe Aptible::CLI::Agent do
  include_context 'mock ssh'

  let(:account) do
    Fabricate(:account, bastion_host: 'bastion.com', dumptruck_port: 45022)
  end
  let(:app) { Fabricate(:app, account: account) }

  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }
  before { subject.stub(:ensure_app) { app } }

  before do
    allow(Kernel).to receive(:exec) do |*args|
      Kernel.system(*args)
    end
  end

  describe '#ps' do
    it 'should set ENV["APTIBLE_CLI_COMMAND"]' do
      subject.send('ps')
      expect(read_mock_env['APTIBLE_CLI_COMMAND']).to eq('ps')
    end

    it 'should construct a proper SSH call' do
      subject.send('ps')

      mock_argv = read_mock_argv
      expect(mock_argv).to include('root@bastion.com')
      expect(mock_argv).to include('45022')
    end
  end
end
