require 'spec_helper'

class App < OpenStruct
end

class Account < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }
  before { subject.stub(:ensure_app) { app } }
  before { subject.stub(:set_env) }
  before { Kernel.stub(:exec) }

  let(:account) do
    Account.new(bastion_host: 'bastion.com', dumptruck_port: 45022)
  end
  let(:app) { App.new(handle: 'hello', account: account) }

  describe '#ps' do
    it 'should set ENV["APTIBLE_CLI_COMMAND"]' do
      expect(subject).to receive(:set_env).with('APTIBLE_CLI_COMMAND', 'ps')
      subject.send('ps')
    end

    it 'should construct a proper SSH call' do
      expect(Kernel).to receive(:exec) do |*args|
        cmd = args.first
        expect(cmd).to match(/ssh.*-p 45022 root@bastion.com/)
      end
      subject.send('ps')
    end
  end
end
