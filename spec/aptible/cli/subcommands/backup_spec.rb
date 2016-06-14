require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:account) { Fabricate(:account) }
  let(:database) { Fabricate(:database, account: account, handle: 'some-db') }
  let!(:backup) do
    # created_at: 2016-06-14 13:24:11 +0000
    Fabricate(:backup, database: database, created_at: Time.at(1465910651))
  end

  let(:messages) { [] }

  before do
    allow(subject).to receive(:fetch_token).and_return(token)
    allow(subject).to receive(:say) { |m| messages << m }
  end

  describe '#backup:restore' do
    it 'fails if the backup cannot be found' do
      expect(Aptible::Api::Backup).to receive(:find).with(1, token: token)
        .and_return(nil)

      expect { subject.send('backup:restore', 1) }
        .to raise_error('Backup #1 not found')
    end

    context 'successful restore' do
      let(:op) { Fabricate(:operation, resource: backup) }

      before do
        expect(Aptible::Api::Backup).to receive(:find).with(1, token: token)
          .and_return(backup)
        expect(subject).to receive(:attach_to_operation_logs).with(op)
      end

      it 'provides a default handle and no disk size' do
        h = 'some-db-at-2016-06-14-13-24-11'

        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to eq(h)
          expect(options[:disk_size]).not_to be_present
          op
        end

        subject.send('backup:restore', 1)
        expect(messages).to eq(["Restoring backup into #{h}"])
      end

      it 'accepts a custom handle and disk size' do
        h = 'some-handle'
        s = 40

        expect(backup).to receive(:create_operation!) do |options|
          expect(options[:handle]).to eq(h)
          expect(options[:disk_size]).to eq(s)
          op
        end

        subject.options = { handle: h, size: s }
        subject.send('backup:restore', 1)
        expect(messages).to eq(["Restoring backup into #{h}"])
      end
    end
  end

  describe '#backup:list' do
    before { 10.times { Fabricate(:backup, database: database) } }
    before { allow(Aptible::Api::Account).to receive(:all) { [account] } }
    before { allow(Aptible::Api::Database).to receive(:all) { [database] } }

    it 'shows backups for a database' do
      subject.send('backup:list', database.handle)
      expect(messages.size).to eq(11)
    end

    it 'allows scoping via environment' do
      subject.options = { environment: database.account.handle }
      subject.send('backup:list', database.handle)
      expect(messages.size).to eq(11)
    end

    it 'fails if the DB is not found' do
      expect { subject.send('backup:list', 'nope') }
        .to raise_error(Thor::Error, 'Could not find database nope')
    end
  end
end
