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
end
