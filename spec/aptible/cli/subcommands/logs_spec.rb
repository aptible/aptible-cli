require 'spec_helper'

describe Aptible::CLI::Agent do
  before do
    allow(subject).to receive(:ask)
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:fetch_token) { 'some token' }
  end

  let(:app) { Fabricate(:app, handle: 'foo') }
  let(:database) { Fabricate(:database, handle: 'bar', status: 'provisioned') }
  let(:service) { Fabricate(:service, app: app) }

  describe '#logs' do
    before { allow(Aptible::Api::Account).to receive(:all) { [app.account] } }

    context 'App resource' do
      before { allow(Aptible::Api::App).to receive(:all) { [app] } }
      before { subject.options = { app: app.handle } }

      it 'should fail if the app is unprovisioned' do
        app.status = 'pending'
        expect { subject.send('logs') }
          .to raise_error(Thor::Error, /Have you deployed foo yet/)
      end

      it 'create a logs operation and connect to the SSH portal' do
        op = double('operation')
        expect(app).to receive(:create_operation!).with(
          type: 'logs', status: 'succeeded'
        ).and_return(op)
        expect(subject).to receive(:exit_with_ssh_portal).with(op, any_args)
        subject.send('logs')
      end
    end

    context 'Database resource' do
      before { allow(Aptible::Api::Database).to receive(:all) { [database] } }
      before { subject.options = { database: database.handle } }

      it 'should fail if the database is unprovisioned' do
        database.status = 'pending'
        expect { subject.send('logs') }
          .to raise_error(Thor::Error, /Have you deployed bar yet/)
      end

      it 'create a logs operation and connect to the SSH portal' do
        op = double('operation')
        expect(database).to receive(:create_operation!).with(
          type: 'logs', status: 'succeeded'
        ).and_return(op)
        expect(subject).to receive(:exit_with_ssh_portal).with(op, any_args)
        subject.send('logs')
      end
    end

    it 'should fail when passed both --app and --database' do
      subject.options = { app: 'foo', database: 'bar' }

      expect { subject.send(:logs) }.to raise_error(/only one of/im)
    end
  end

  describe '#logs_from_archive' do
    context 'using string-matches' do
      let(:files) { %w(file_1 file_2) }

      before do
        subject.options = {
          region: 'some-region',
          bucket: 'some-bucket',
          decryption_keys: 'mykey',
          string_matches: 'foo',
          download_location: './'
        }
        subject.stub(:info_from_path) { { shasum: 'foo' } }
        subject.stub(:encryption_key) { subject.options[:decryption_keys] }
      end

      it 'download all files' do
        expect(subject).to receive(:ensure_aws_creds)
        expect(subject).to receive(:validate_log_search_options)
          .with(subject.options)

        expect(subject).to receive(:find_s3_files_by_string_match)
          .with(
            subject.options[:region],
            subject.options[:bucket],
            subject.options[:stack],
            subject.options[:string_matches]
          ).and_return(files)

        files.each do |f|
          expect(subject).to receive(:decrypt_and_translate_s3_file)
            .with(
              f,
              subject.options[:decryption_keys],
              subject.options[:region],
              subject.options[:bucket],
              subject.options[:download_location]
            )
        end
        subject.send('logs_from_archive')
      end
    end

    context 'using app/database/proxy  id' do
      let(:files) { %w(file_1 file_2) }

      before do
        subject.options = {
          region: 'some-region',
          bucket: 'some-bucket',
          stack: 'mystack',
          decryption_keys: 'mykey',
          app_id: 123,
          download_location: './'
        }
        subject.stub(:info_from_path) { { shasum: 'foo' } }
        subject.stub(:encryption_key) { subject.options[:decryption_keys] }
      end

      it 'download all files' do
        expect(subject).to receive(:ensure_aws_creds)
        expect(subject).to receive(:validate_log_search_options)
          .with(subject.options)

        expect(subject).to receive(:find_s3_files_by_attrs)
          .with(
            subject.options[:region],
            subject.options[:bucket],
            subject.options[:stack],
            { type: 'apps', id: 123 },
            nil
          ).and_return(files)

        files.each do |f|
          expect(subject).to receive(:decrypt_and_translate_s3_file)
            .with(
              f,
              subject.options[:decryption_keys],
              subject.options[:region],
              subject.options[:bucket],
              subject.options[:download_location]
            )
        end
        subject.send('logs_from_archive')
      end
    end

    context 'using container id' do
      let(:files) { %w(file_1 file_2) }

      before do
        subject.options = {
          region: 'some-region',
          bucket: 'some-bucket',
          stack: 'mystack',
          decryption_keys: 'mykey',
          container_id:
            '9080b96447f98b31ef9831d5fd98b09e3c5c545269734e2e825644571152457c',
          download_location: './'
        }
        subject.stub(:info_from_path) { { shasum: 'foo' } }
        subject.stub(:encryption_key) { subject.options[:decryption_keys] }
      end

      it 'download all files' do
        expect(subject).to receive(:ensure_aws_creds)
        expect(subject).to receive(:validate_log_search_options)
          .with(subject.options)

        expect(subject).to receive(:find_s3_files_by_attrs)
          .with(
            subject.options[:region],
            subject.options[:bucket],
            subject.options[:stack],
            { container_id: subject.options[:container_id] },
            nil
          ).and_return(files)

        files.each do |f|
          expect(subject).to receive(:decrypt_and_translate_s3_file)
            .with(
              f,
              subject.options[:decryption_keys],
              subject.options[:region],
              subject.options[:bucket],
              subject.options[:download_location]
            )
        end
        subject.send('logs_from_archive')
      end
    end
  end
end
