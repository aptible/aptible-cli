require 'spec_helper'

describe Aptible::CLI::Helpers::Database do
  subject { Class.new.send(:include, described_class).new }

  describe '#validate_image_type' do
    let(:pg) do
      Fabricate(:database_image, type: 'postgresql', version: '10')
    end

    let(:redis) do
      Fabricate(:database_image, type: 'redis', version: '9.4')
    end

    let(:token) { 'some-token' }

    before do
      allow(subject).to receive(:fetch_token).and_return(token)
      allow(Aptible::Api::DatabaseImage).to receive(:all)
        .and_return([pg, redis])
    end

    it 'Raises an error if provided an invalid type' do
      bad_type = 'cassandra'
      err = "No Database Image of type \"#{bad_type}\", " \
            "valid types: #{pg.type}, #{redis.type}"
      expect do
        subject.validate_image_type(bad_type)
      end.to raise_error(Thor::Error, err)
    end

    it 'Retruns true when provided a valid type' do
      expect(subject.validate_image_type(pg.type)).to be(true)
    end
  end

  describe '#derive_account_from_conns' do
    let(:stack) { Fabricate(:stack) }
    let(:account1) { Fabricate(:account, handle: 'account1', stack: stack) }
    let(:account2) { Fabricate(:account, handle: 'account2', stack: stack) }
    let(:app1) { Fabricate(:app, account: account1) }
    let(:app2) { Fabricate(:app, account: account2) }

    let(:raw_rds_resource) do
      Fabricate(:external_aws_resource, resource_type: 'aws_rds_db_instance')
    end

    let(:rds_db) do
      Aptible::CLI::Helpers::Database::RdsDatabase.new(
        'aws:rds::test-db',
        raw_rds_resource.id,
        raw_rds_resource.created_at,
        raw_rds_resource
      )
    end

    let(:conn1) do
      double('connection1', present?: true, app: app1)
    end

    let(:conn2) do
      double('connection2', present?: true, app: app2)
    end

    before do
      allow(app1).to receive(:account).and_return(account1)
      allow(app2).to receive(:account).and_return(account2)
    end

    context 'when connections are empty' do
      it 'returns nil' do
        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          []
        )

        result = subject.derive_account_from_conns(rds_db)
        expect(result).to be_nil
      end
    end

    context 'when no preferred account is specified' do
      it 'returns the account from the first connection' do
        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          [conn1, conn2]
        )

        result = subject.derive_account_from_conns(rds_db)
        expect(result).to eq(account1)
      end

      it 'handles a single connection' do
        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          [conn2]
        )

        result = subject.derive_account_from_conns(rds_db)
        expect(result).to eq(account2)
      end
    end

    context 'when a preferred account is specified' do
      it 'returns the matching account when found' do
        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          [conn1, conn2]
        )

        result = subject.derive_account_from_conns(rds_db, account2)
        expect(result).to eq(account2)
      end

      it 'returns nil when no matching connection is found' do
        account3 = Fabricate(:account, handle: 'account3', stack: stack)
        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          [conn1, conn2]
        )

        result = subject.derive_account_from_conns(rds_db, account3)
        expect(result).to be_nil
      end

      it 'skips connections where conn.present? is false' do
        conn_not_present = double('connection_not_present', present?: false)
        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          [conn_not_present, conn2]
        )

        result = subject.derive_account_from_conns(rds_db, account2)
        expect(result).to eq(account2)
      end

      it 'returns the first matching account when multiple matches exist' do
        app1_duplicate = Fabricate(:app, account: account1)
        allow(app1_duplicate).to receive(:account).and_return(account1)
        conn1_duplicate = double('connection1_dup',
                                 present?: true,
                                 app: app1_duplicate)

        raw_rds_resource.instance_variable_set(
          :@app_external_aws_rds_connections,
          [conn1, conn1_duplicate]
        )

        result = subject.derive_account_from_conns(rds_db, account1)
        expect(result).to eq(account1)
      end
    end
  end
end
