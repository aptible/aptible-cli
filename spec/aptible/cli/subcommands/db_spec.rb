require 'ostruct'
require 'spec_helper'

class Database < OpenStruct
end

class Account < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }
  before { subject.stub(:random_local_port) { 4242 } }
  before { subject.stub(:establish_connection) }

  let(:account) do
    Account.new(bastion_host: 'localhost',
                dumptruck_port: 1234,
                handle: 'aptible')
  end
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

      # db:tunnel should also explain each component of the URL:
      expect(subject).to receive(:say).exactly(6).times
      subject.send('db:tunnel', 'foobar')
    end
  end

  describe '#db:list' do
    context 'when no account is specified' do
      it 'prints out the grouped database handles for all accounts' do
        setup_prod_and_staging_accounts
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
        setup_prod_and_staging_accounts
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
        setup_prod_and_staging_accounts
        allow(subject).to receive(:say)

        subject.options = { environment: 'foo' }
        expect { subject.send('db:list') }.to raise_error(
          'Specified account does not exist'
        )
      end
    end
  end

  def setup_prod_and_staging_accounts
    staging_redis = Database.new(handle: 'staging-redis-db')
    staging_postgres = Database.new(handle: 'staging-postgres-db')
    prod_elsearch = Database.new(handle: 'prod-elsearch-db')
    prod_postgres = Database.new(handle: 'prod-postgres-db')

    stub_local_token_with('the-token')
    setup_new_accounts_with_dbs(
      token: 'the-token',
      account_db_mapping: {
        'staging' => [staging_redis, staging_postgres],
        'production' => [prod_elsearch, prod_postgres]
      }
    )
  end

  def setup_new_accounts_with_dbs(options)
    token = options.fetch(:token)
    account_db_mapping = options.fetch(:account_db_mapping)

    accounts_with_dbs = []
    account_db_mapping.each do |account_handle, dbs|
      account = Account.new(handle: account_handle, databases: dbs)
      accounts_with_dbs << account
    end

    allow(Aptible::Api::Account).to receive(:all).with(token: token)
      .and_return(accounts_with_dbs)
  end

  def stub_local_token_with(token)
    allow(subject).to receive(:fetch_token).and_return(token)
  end
end
