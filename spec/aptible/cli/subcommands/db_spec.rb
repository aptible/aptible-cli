require 'spec_helper'

class SocatHelperMock < OpenStruct
end

describe Aptible::CLI::Agent do
  before do
    allow(subject).to receive(:ask)
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:fetch_token) { double 'token' }
  end

  let(:handle) { 'foobar' }
  let(:database) { Fabricate(:database, handle: handle) }
  let(:socat_helper) { SocatHelperMock.new(port: 4242) }

  describe '#db:create' do
    let(:db) { Fabricate(:database) }
    let(:op) { Fabricate(:operation) }
    let(:account) { Fabricate(:account) }

    before do
      allow(Aptible::Api::Account).to receive(:all).and_return([account])
      allow(db).to receive(:reload).and_return(db)
      allow(op).to receive(:errors).and_return(Aptible::Resource::Errors.new)
    end

    it 'creates a new DB' do
      expect(account).to receive(:create_database!)
        .with(handle: 'foo', type: 'postgresql')
        .and_return(db)

      expect(db).to receive(:create_operation)
        .with(type: 'provision')
        .and_return(op)

      expect(subject).to receive(:attach_to_operation_logs)
        .with(op)

      subject.options = { type: 'postgresql' }
      subject.send('db:create', 'foo')
    end

    it 'creates a new DB with a container size' do
      expect(account).to receive(:create_database!)
        .with(handle: 'foo', type: 'postgresql', initial_container_size: 1024)
        .and_return(db)

      expect(db).to receive(:create_operation)
        .with(type: 'provision', container_size: 1024)
        .and_return(op)

      expect(subject).to receive(:attach_to_operation_logs)
        .with(op)

      subject.options = { type: 'postgresql', container_size: 1024 }
      subject.send('db:create', 'foo')
    end

    it 'creates a new DB with a disk size' do
      expect(account).to receive(:create_database!)
        .with(handle: 'foo', type: 'postgresql', initial_disk_size: 200)
        .and_return(db)

      expect(db).to receive(:create_operation)
        .with(type: 'provision', disk_size: 200)
        .and_return(op)

      expect(subject).to receive(:attach_to_operation_logs)
        .with(op)

      subject.options = { type: 'postgresql', size: 200 }
      subject.send('db:create', 'foo')
    end

    it 'deprovisions the database if the operation cannot be created' do
      op.errors.full_messages << 'oops!'

      expect(account).to receive(:create_database!).and_return(db)

      expect(db).to receive(:create_operation)
        .with(type: 'provision')
        .once.ordered.and_return(op)

      expect(db).to receive(:create_operation!)
        .with(type: 'deprovision')
        .once.ordered

      expect { subject.send('db:create', 'foo') }.to raise_error(/oops/im)
    end
  end

  describe '#db:tunnel' do
    it 'should fail if database is non-existent' do
      allow(Aptible::Api::Database).to receive(:all) { [] }
      expect do
        subject.send('db:tunnel', handle)
      end.to raise_error("Could not find database #{handle}")
    end

    context 'valid database' do
      before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

      it 'prints a message explaining how to connect' do
        cred = Fabricate(:database_credential, default: true, type: 'foo',
                                               database: database)

        expect(subject).to receive(:with_local_tunnel).with(cred, 0)
          .and_yield(socat_helper)

        subject.send('db:tunnel', handle)

        local_url = 'postgresql://aptible:password@localhost.aptible.in:4242/db'

        expect(captured_logs)
          .to match(/creating foo tunnel to foobar/i)
        expect(captured_logs)
          .to match(/connect at #{Regexp.escape(local_url)}/i)

        expect(captured_logs).to match(/host: localhost\.aptible\.in/i)
        expect(captured_logs).to match(/port: 4242/i)
        expect(captured_logs).to match(/username: aptible/i)
        expect(captured_logs).to match(/password: password/i)
        expect(captured_logs).to match(/database: db/i)
      end

      it 'defaults to a default credential' do
        ok = Fabricate(:database_credential, default: true, database: database)
        Fabricate(:database_credential, database: database, type: 'foo')
        Fabricate(:database_credential, database: database, type: 'bar')

        expect(subject).to receive(:with_local_tunnel).with(ok, 0)

        subject.send('db:tunnel', handle)

        expect(captured_logs).to match(/use --type type/i)
        expect(captured_logs).to match(/valid types.*foo.*bar/i)
      end

      it 'supports --type' do
        subject.options = { type: 'foo' }

        Fabricate(:database_credential, default: true, database: database)
        ok = Fabricate(:database_credential, type: 'foo', database: database)
        Fabricate(:database_credential, type: 'bar', database: database)

        expect(subject).to receive(:with_local_tunnel).with(ok, 0)
        subject.send('db:tunnel', handle)
      end

      it 'fails when there is no default database credential nor type' do
        Fabricate(:database_credential, default: false, database: database)

        expect { subject.send('db:tunnel', handle) }
          .to raise_error(/no default credential/im)
      end

      it 'fails when the type is incorrect' do
        subject.options = { type: 'bar' }

        Fabricate(:database_credential, type: 'foo', database: database)

        expect { subject.send('db:tunnel', handle) }
          .to raise_error(/no credential with type bar/im)
      end

      it 'fails when the database is not provisioned' do
        allow(database).to receive(:status) { 'pending' }

        expect { subject.send('db:tunnel', handle) }
          .to raise_error(/foobar is not provisioned/im)
      end

      context 'v1 stack' do
        before do
          allow(database.account.stack).to receive(:version) { 'v1' }
        end

        it 'falls back to the database itself if no type is given' do
          expect(subject).to receive(:with_local_tunnel).with(database, 0)
          subject.send('db:tunnel', handle)
        end

        it 'falls back to the database itself if type matches' do
          subject.options = { type: 'bar' }
          allow(database).to receive(:type) { 'bar' }

          expect(subject).to receive(:with_local_tunnel).with(database, 0)
          subject.send('db:tunnel', handle)
        end

        it 'does not fall back to the database itself if type mismatches' do
          subject.options = { type: 'bar' }
          allow(database).to receive(:type) { 'foo' }

          expect { subject.send('db:tunnel', handle) }
            .to raise_error(/no credential with type bar/im)
        end

        it 'does not suggest other types that do not exist' do
          expect(subject).to receive(:with_local_tunnel).with(database, 0)

          subject.send('db:tunnel', handle)

          expect(captured_logs).not_to match(/use --type type/i)
        end
      end
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
      allow(subject).to receive(:fetch_token) { token }
      allow(Aptible::Api::Account).to receive(:all).with(token: token)
        .and_return([staging, prod])
    end

    context 'when no account is specified' do
      it 'prints out the grouped database handles for all accounts' do
        subject.send('db:list')

        expect(captured_output_text).to include('=== staging')
        expect(captured_output_text).to include('staging-redis-db')
        expect(captured_output_text).to include('staging-postgres-db')

        expect(captured_output_text).to include('=== production')
        expect(captured_output_text).to include('prod-elsearch-db')
        expect(captured_output_text).to include('prod-postgres-db')
      end
    end

    context 'when a valid account is specified' do
      it 'prints out the database handles for the account' do
        subject.options = { environment: 'staging' }
        subject.send('db:list')

        expect(captured_output_text).to include('=== staging')
        expect(captured_output_text).to include('staging-redis-db')
        expect(captured_output_text).to include('staging-postgres-db')

        expect(captured_output_text).not_to include('=== production')
        expect(captured_output_text).not_to include('prod-elsearch-db')
        expect(captured_output_text).not_to include('prod-postgres-db')
      end
    end

    context 'when an invalid account is specified' do
      it 'prints out an error' do
        subject.options = { environment: 'foo' }
        expect { subject.send('db:list') }
          .to raise_error('Specified account does not exist')
      end
    end
  end

  describe '#db:backup' do
    before { allow(Aptible::Api::Account).to receive(:all) { [account] } }
    before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

    let(:op) { Fabricate(:operation) }

    it 'allows creating a new backup' do
      expect(database).to receive(:create_operation!)
        .with(type: 'backup').and_return(op)
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:backup', handle)

      expect(captured_logs).to match(/backing up foobar/i)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('db:backup', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end

  describe '#db:reload' do
    before { allow(Aptible::Api::Account).to receive(:all) { [account] } }
    before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

    let(:op) { Fabricate(:operation) }

    it 'allows reloading a database' do
      expect(database).to receive(:create_operation!)
        .with(type: 'reload').and_return(op)
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:reload', handle)

      expect(captured_logs).to match(/reloading foobar/i)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('db:reload', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end

  describe '#db:restart' do
    before { allow(Aptible::Api::Account).to receive(:all) { [account] } }
    before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

    let(:op) { Fabricate(:operation) }

    it 'allows restarting a database' do
      expect(database).to receive(:create_operation!)
        .with(type: 'restart').and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:restart', handle)

      expect(captured_logs).to match(/restarting foobar/i)
    end

    it 'allows restarting a database with a container size' do
      expect(database).to receive(:create_operation!)
        .with(type: 'restart', container_size: 40).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.options = { container_size: 40 }
      subject.send('db:restart', handle)

      expect(captured_logs).to match(/restarting foobar/i)
    end

    it 'allows restarting a database with a disk size' do
      expect(database).to receive(:create_operation!)
        .with(type: 'restart', disk_size: 40).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.options = { size: 40 }
      subject.send('db:restart', handle)

      expect(captured_logs).to match(/restarting foobar/i)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('db:restart', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end

  describe '#db:url' do
    let(:databases) { [database] }
    before { expect(Aptible::Api::Database).to receive(:all) { databases } }

    it 'fails if the DB is not found' do
      expect { subject.send('db:url', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end

    context 'valid database' do
      it 'returns the URL of a specified DB' do
        cred = Fabricate(
          :database_credential, default: true, type: 'foo', database: database
        )
        expect(database).not_to receive(:connection_url)
        subject.send('db:url', handle)
        expect(captured_output_text.chomp).to eq(cred.connection_url)
      end

      it 'fails if multiple DBs are found' do
        databases << database

        expect { subject.send('db:url', handle) }
          .to raise_error(/Multiple databases/)
      end

      context 'v1 stack' do
        before do
          allow(database.account.stack).to receive(:version) { 'v1' }
        end

        it 'returns the URL of a specified DB' do
          connection_url = 'postgresql://aptible-v1:password@lega.cy:4242/db'
          expect(database).to receive(:connection_url)
            .and_return(connection_url)

          subject.send('db:url', handle)

          expect(captured_output_text.chomp).to eq(connection_url)
        end
      end
    end
  end
end
