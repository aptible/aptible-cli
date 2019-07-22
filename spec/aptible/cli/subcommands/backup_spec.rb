require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:account) { Fabricate(:account, handle: 'test') }
  let(:alt_account) { Fabricate(:account, handle: 'alt') }
  let(:database) { Fabricate(:database, account: account, handle: 'some-db') }
  let!(:backup) do
    # created_at: 2016-06-14 13:24:11 +0000
    Fabricate(
      :backup,
      database: database, created_at: Time.at(1465910651), account: account
    )
  end

  let(:default_handle) { 'some-db-at-2016-06-14-13-24-11' }

  before do
    allow(subject).to receive(:fetch_token).and_return(token)
    allow(Aptible::Api::Account).to receive(:all) { [account, alt_account] }
  end

  describe '#backup:restore' do
    it 'fails if the backup cannot be found' do
      expect(Aptible::Api::Backup).to receive(:find)
        .with(1, token: token).and_return(nil)

      expect { subject.send('backup:restore', 1) }
        .to raise_error('Backup #1 not found')
    end

    context 'successful restore' do
      let(:op) { Fabricate(:operation, resource: backup) }

      before do
        expect(Aptible::Api::Backup).to receive(:find)
          .with(1, token: token).and_return(backup)
      end

      it 'provides a default handle and no disk size' do
        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to eq(default_handle)
          expect(options[:disk_size]).not_to be_present
          expect(options[:destination_account]).not_to be_present
          op
        end

        expect(subject).to receive(:attach_to_operation_logs).with(op) do
          Fabricate(:database, account: account, handle: default_handle)
        end

        subject.send('backup:restore', 1)

        expect(captured_logs)
          .to match(/restoring backup into #{default_handle}/im)
      end

      it 'accepts a handle' do
        h = 'some-handle'

        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to eq(h)
          expect(options[:container_size]).to be_nil
          expect(options[:disk_size]).to be_nil
          expect(options[:destination_account]).not_to be_present
          op
        end

        expect(subject).to receive(:attach_to_operation_logs).with(op) do
          Fabricate(:database, account: account, handle: h)
        end

        subject.options = { handle: h }
        subject.send('backup:restore', 1)
        expect(captured_logs).to match(/restoring backup into #{h}/im)
      end

      it 'accepts a container size' do
        s = 40

        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to be_present
          expect(options[:container_size]).to eq(s)
          expect(options[:disk_size]).to be_nil
          expect(options[:destination_account]).not_to be_present
          op
        end

        expect(subject).to receive(:attach_to_operation_logs).with(op) do
          Fabricate(:database, account: account, handle: default_handle)
        end

        subject.options = { container_size: s }
        subject.send('backup:restore', 1)
      end

      it 'accepts a disk size' do
        s = 40

        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to be_present
          expect(options[:container_size]).to be_nil
          expect(options[:disk_size]).to eq(s)
          expect(options[:destination_account]).not_to be_present
          op
        end

        expect(subject).to receive(:attach_to_operation_logs).with(op) do
          Fabricate(:database, account: account, handle: default_handle)
        end

        subject.options = { size: s }
        subject.send('backup:restore', 1)
      end

      it 'accepts an destination environment' do
        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to be_present
          expect(options[:destination_account]).to eq(alt_account)
          op
        end

        expect(subject).to receive(:attach_to_operation_logs).with(op) do
          Fabricate(:database, account: alt_account, handle: default_handle)
        end

        subject.options = { environment: 'alt' }
        subject.send('backup:restore', 1)
      end
    end
  end

  describe '#backup:list' do
    before { allow(Aptible::Api::Account).to receive(:all) { [account] } }
    before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

    before do
      m = allow(database).to receive(:each_backup)

      [
        1.day, 2.days, 3.days, 4.days,
        5.days, 2.weeks, 3.weeks, 1.month,
        1.year
      ].each do |age|
        b = Fabricate(:backup, database: database, created_at: age.ago)
        m.and_yield(b)
      end
    end

    # The default value isn't set when we run sepcs
    before { subject.options = { max_age: '1w' } }

    it 'can show a subset of backups' do
      subject.send('backup:list', database.handle)
      expect(captured_output_text.split("\n").size).to eq(5)
    end

    it 'allows scoping via environment' do
      subject.options = { max_age: '1w', environment: database.account.handle }
      subject.send('backup:list', database.handle)
      expect(captured_output_text.split("\n").size).to eq(5)
    end

    it 'shows more backups if requested' do
      subject.options = { max_age: '2y' }
      subject.send('backup:list', database.handle)
      expect(captured_output_text.split("\n").size).to eq(9)
    end

    it 'errors out if max_age is invalid' do
      subject.options = { max_age: 'foobar' }
      expect { subject.send('backup:list', database.handle) }
        .to raise_error(Thor::Error, 'Invalid age: foobar')
    end

    it 'fails if the DB is not found' do
      expect { subject.send('backup:list', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end
end
