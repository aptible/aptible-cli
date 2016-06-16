require 'spec_helper'

class SocatHelperMock < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }

  let(:handle) { 'foobar' }
  let(:database) { Fabricate(:database, handle: handle) }
  let(:socat_helper) { SocatHelperMock.new(port: 4242) }

  describe '#db:tunnel' do
    it 'should fail if database is non-existent' do
      allow(Aptible::Api::Database).to receive(:all) { [] }
      expect do
        subject.send('db:tunnel', handle)
      end.to raise_error("Could not find database #{handle}")
    end

    it 'should print a message about how to connect' do
      allow(Aptible::Api::Database).to receive(:all) { [database] }
      local_url = 'postgresql://aptible:password@127.0.0.1:4242/db'

      expect(subject).to receive(:with_local_tunnel).with(database, 0)
        .and_yield(socat_helper)
      expect(subject).to receive(:say).with('Creating tunnel...', :green)
      expect(subject).to receive(:say).with("Connect at #{local_url}", :green)

      # db:tunnel should also explain each component of the URL:
      expect(subject).to receive(:say).exactly(7).times
      subject.send('db:tunnel', handle)
    end
  end

  describe '#db:list' do
    before do
      staging = Fabricate(:account, handle: 'staging')
      prod = Fabricate(:account, handle: 'production')

      [[staging, 'staging-redis-db'], [staging, 'staging-postgres-db'],
       [prod, 'prod-elsearch-db'], [prod, 'prod-postgres-db']].each do |a, h|
        Fabricate(:database, account: a, handle: h)
      end

      token = 'the-token'
      allow(subject).to receive(:fetch_token).and_return(token)
      allow(Aptible::Api::Account).to receive(:all).with(token: token)
        .and_return([staging, prod])
    end

    context 'when no account is specified' do
      it 'prints out the grouped database handles for all accounts' do
        allow(subject).to receive(:say)

        subject.send('db:list')

        expect(subject).to have_received(:say).with('=== staging')
        expect(subject).to have_received(:say).with('staging-redis-db')
        expect(subject).to have_received(:say).with('staging-postgres-db')

        expect(subject).to have_received(:say).with('=== production')
        expect(subject).to have_received(:say).with('prod-elsearch-db')
        expect(subject).to have_received(:say).with('prod-postgres-db')
      end
    end

    context 'when a valid account is specified' do
      it 'prints out the database handles for the account' do
        allow(subject).to receive(:say)

        subject.options = { environment: 'staging' }
        subject.send('db:list')

        expect(subject).to have_received(:say).with('=== staging')
        expect(subject).to have_received(:say).with('staging-redis-db')
        expect(subject).to have_received(:say).with('staging-postgres-db')

        expect(subject).to_not have_received(:say).with('=== production')
        expect(subject).to_not have_received(:say).with('prod-elsearch-db')
        expect(subject).to_not have_received(:say).with('prod-postgres-db')
      end
    end

    context 'when an invalid account is specified' do
      it 'prints out an error' do
        allow(subject).to receive(:say)

        subject.options = { environment: 'foo' }
        expect { subject.send('db:list') }.to raise_error(
          'Specified account does not exist'
        )
      end
    end
  end

  describe '#db:backup' do
    before { allow(Aptible::Api::Account).to receive(:all) { [account] } }
    before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

    let(:op) { Fabricate(:operation) }

    it 'allows creating a new backup' do
      expect(database).to receive(:create_operation!).and_return(op)
      expect(subject).to receive(:say).with('Backing up foobar...')
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:backup', handle)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('db:backup', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end
end
