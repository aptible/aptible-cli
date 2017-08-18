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

        expect(subject).to receive(:say)
          .with('Creating foo tunnel to foobar...', :green)

        local_url = 'postgresql://aptible:password@localhost.aptible.in:4242/db'
        expect(subject).to receive(:say)
          .with("Connect at #{local_url}", :green)

        # db:tunnel should also explain each component of the URL and suggest
        # the --type argument:
        expect(subject).to receive(:say).exactly(9).times
        subject.send('db:tunnel', handle)
      end

      it 'defaults to a default credential' do
        ok = Fabricate(:database_credential, default: true, database: database)
        Fabricate(:database_credential, database: database, type: 'foo')
        Fabricate(:database_credential, database: database, type: 'bar')

        messages = []
        allow(subject).to receive(:say) { |m, *| messages << m }
        expect(subject).to receive(:with_local_tunnel).with(ok, 0)

        subject.send('db:tunnel', handle)

        expect(messages.grep(/use --type type/im)).not_to be_empty
        expect(messages.grep(/valid types.*foo.*bar/im)).not_to be_empty
      end

      it 'supports --type' do
        subject.options = { type: 'foo' }

        Fabricate(:database_credential, default: true, database: database)
        ok = Fabricate(:database_credential, type: 'foo', database: database)
        Fabricate(:database_credential, type: 'bar', database: database)

        allow(subject).to receive(:say)
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
          allow(subject).to receive(:say)
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
          messages = []
          allow(subject).to receive(:say) { |m, *| messages << m }
          expect(subject).to receive(:with_local_tunnel).with(database, 0)

          subject.send('db:tunnel', handle)

          expect(messages.grep(/use --type type/im)).to be_empty
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
      expect(database).to receive(:create_operation!)
        .with(type: 'backup').and_return(op)
      expect(subject).to receive(:say).with('Backing up foobar...')
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:backup', handle)
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
      expect(subject).to receive(:say).with('Reloading foobar...')
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:reload', handle)
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

      expect(subject).to receive(:say).with('Restarting foobar...')
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.send('db:restart', handle)
    end

    it 'allows restarting a database with a container size' do
      expect(database).to receive(:create_operation!)
        .with(type: 'restart', container_size: 40).and_return(op)

      expect(subject).to receive(:say).with('Restarting foobar...')
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.options = { container_size: 40 }
      subject.send('db:restart', handle)
    end

    it 'allows restarting a database with a disk size' do
      expect(database).to receive(:create_operation!)
        .with(type: 'restart', disk_size: 40).and_return(op)

      expect(subject).to receive(:say).with('Restarting foobar...')
      expect(subject).to receive(:attach_to_operation_logs).with(op)

      subject.options = { size: 40 }
      subject.send('db:restart', handle)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('db:restart', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end

  describe '#db:url' do
    let(:databases) { [database] }
    before { expect(Aptible::Api::Database).to receive(:all) { databases } }

    it 'returns the URL of a specified DB' do
      expect(subject).to receive(:say).with(database.connection_url)
      subject.send('db:url', handle)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('db:url', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end

    it 'fails if multiple DBs are found' do
      databases << database

      expect { subject.send('db:url', handle) }
        .to raise_error(/Multiple databases/)
    end
  end
end
