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

  describe 'logs_from_archive' do
    around do |example| 
      ClimateControl.modify(AWS_ACCESS_KEY_ID: 'foo', AWS_SECRET_ACCESS_KEY: 'bar') do
         example.run
      end
    end

    context '--string-matches searches' do     
      it 'do not also allow searching by type' do
        subject.options = { app_id: '123', string_matches: ['foo'] }
  
        m = 'cannot pass --app-id, --database-id, or --proxy-id when using --string-matches'
        expect{ subject.send(:logs_from_archive) }.to raise_error(/#{m}/)
      end

      it 'ignores --start-date and --end-date options' do
        subject.options = { start_date: '11/22/63', string_matches: ['foo'] }
        m = '--start-date/--end-date cannot be used'
        expect{ subject.send(:logs_from_archive) }.to raise_error(/#{m}/)
      end

      it 'uses find_s3_files_by_string_match' do
         skip
      end
    end

    context '--TYPE-ID searches' do 
      it 'You must path both --start-date and --end-date' do
        subject.options = { app_id: '123', start_date: '11/22/63' }
  
        m = 'You must pass both --start-date and --end-date'
        expect{ subject.send(:logs_from_archive) }.to raise_error(/#{m}/)
      end

      it 'uses find_s3_files_by_type_id' do
        skip
     end
    end
  end
end
