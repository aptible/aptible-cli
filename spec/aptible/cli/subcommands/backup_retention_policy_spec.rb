require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:account) { Fabricate(:account, handle: 'test') }
  let(:database) { Fabricate(:database, account: account, handle: 'some-db') }
  let!(:policy) do
    # created_at: 2016-06-14 13:24:11 +0000
    Fabricate(:backup_retention_policy, account: account)
  end

  let(:default_handle) { 'some-db-at-2016-06-14-13-24-11' }

  before do
    allow(subject).to receive(:fetch_token).and_return(token)
    allow(Aptible::Api::Account).to receive(:all) { [account] }
  end

  describe '#backup_retention_policy' do
    it 'raises an error if the environment has no policy' do
      allow(account).to receive(:backup_retention_policies).and_return([])
      expect { subject.backup_retention_policy('test') }
        .to raise_error(/does not have a custom backup retention policy/)
    end

    it "prints the enviroment's current policy" do
      subject.backup_retention_policy('test')
      out = captured_output_text
      expect(out).to match(/daily: 30/i)
      expect(out).to match(/monthly: 12/i)
      expect(out).to match(/yearly: 6/i)
      expect(out).to match(/make copy: true/i)
      expect(out).to match(/keep final: true/i)
      expect(out).to match(/environment: test/i)
    end
  end

  describe '#backup_retention_policy:set' do
    it 'requires all attributes if the environment has no policy' do
      allow(account).to receive(:backup_retention_policies).and_return([])
      opts = {
        daily: 3,
        monthly: 2,
        yearly: 1,
        make_copy: false,
        keep_final: true
      }

      opts.each_key do |k|
        missing_opts = opts.clone
        missing_opts.delete(k)

        subject.options = missing_opts
        expect { subject.send('backup_retention_policy:set', 'test') }
          .to raise_error(/please specify all attributes/i)
      end

      expect(account).to receive(:create_backup_retention_policy!)
        .with(**opts).and_return(Fabricate(:backup_retention_policy))
      subject.options = opts
      subject.send('backup_retention_policy:set', 'test')
    end

    it 'merges provided options with the current policy' do
      expected_opts = {
        daily: 5,
        monthly: policy.monthly,
        yearly: policy.yearly,
        make_copy: policy.make_copy,
        keep_final: false
      }

      expect(account).to receive(:create_backup_retention_policy!)
        .with(**expected_opts).and_return(Fabricate(:backup_retention_policy))
      subject.options = { daily: 5, keep_final: false, force: true }
      subject.send('backup_retention_policy:set', 'test')
    end

    it 'prompts the user if the new policy retains fewer backups' do
      subject.options = { daily: 0 }

      # Reject Prompt
      expect(subject).to receive(:yes?).with(/do you want to proceed/i)

      expect { subject.send('backup_retention_policy:set', 'test') }
        .to raise_error(/aborting/i)

      # Accept Prompt
      expect(subject).to receive(:yes?).with(/do you want to proceed/i)
        .and_return(true)

      expect(account).to receive(:create_backup_retention_policy!)
        .and_return(Fabricate(:backup_retention_policy))

      subject.send('backup_retention_policy:set', 'test')
    end

    it '--force skips the confirmation promt' do
      subject.options = { make_copy: false }

      # Reject Prompt
      expect(subject).to receive(:yes?).with(/do you want to proceed/i)

      expect { subject.send('backup_retention_policy:set', 'test') }
        .to raise_error(/aborting/i)

      # --force
      subject.options[:force] = true
      expect(account).to receive(:create_backup_retention_policy!)
        .and_return(Fabricate(:backup_retention_policy))

      subject.send('backup_retention_policy:set', 'test')
    end
  end
end
