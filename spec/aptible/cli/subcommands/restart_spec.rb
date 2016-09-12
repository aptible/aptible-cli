require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:app) { Fabricate(:app) }
  let(:operation) { Fabricate(:operation, resource: app) }
  before { allow(subject).to receive(:ensure_app).and_return(app) }

  describe '#restart' do
    it 'restarts the app' do
      expect(app).to receive(:create_operation!).with(type: 'restart')
        .and_return(operation)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)

      subject.send('restart')
    end

    it 'does not require the --force flag for a regular restart' do
      app.account.type = 'production'
      expect(app).to receive(:create_operation!)
      expect(subject).to receive(:attach_to_operation_logs)

      subject.send('restart')
    end

    it 'uses captain_comeback_restart if --simulate-oom is passed' do
      subject.options = { simulate_oom: true }
      expect(app).to receive(:create_operation!)
        .with(type: 'captain_comeback_restart')
        .and_return(operation)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)

      subject.send('restart')
    end

    it 'fails a CC restart if the --force flag is not passed for a prod app' do
      subject.options = { simulate_oom: true }
      app.account.type = 'production'
      expect(app).not_to receive(:create_operation!)
      expect(subject).not_to receive(:attach_to_operation_logs)

      expect { subject.send('restart') }.to raise_error(/are you sure/i)
    end

    it 'creates a CC restart if the --force flag is passed for a prod app' do
      subject.options = { simulate_oom: true, force: true }
      app.account.type = 'production'
      expect(app).to receive(:create_operation!)
      expect(subject).to receive(:attach_to_operation_logs)

      subject.send('restart')
    end
  end
end
