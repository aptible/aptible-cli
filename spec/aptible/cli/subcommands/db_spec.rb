require 'ostruct'
require 'spec_helper'

class Database < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }
  before { subject.stub(:random_local_port) { 4242 } }
  before { subject.stub(:establish_connection) }

  let(:database) do
    Database.new(
      type: 'postgresql',
      handle: 'foobar',
      passphrase: 'password',
      connection_url: 'postgresql://aptible:password@10.252.1.125:49158/db'
    )
  end

  describe '#db:tunnel' do
    it 'should fail if database is non-existent' do
      allow(Aptible::Api::Database).to receive(:all) { [] }
      expect do
        subject.send('db:tunnel', 'foobar')
      end.to raise_error('Could not find database foobar')
    end

    it 'should print a message about how to connect' do
      allow(Aptible::Api::Database).to receive(:all) { [database] }
      local_url = 'postgresql://aptible:password@127.0.0.1:4242/db'
      expect(subject).to receive(:say).with('Creating tunnel...', :green)
      expect(subject).to receive(:say).with("Connect at #{local_url}", :green)
      subject.send('db:tunnel', 'foobar')
    end
  end
end
