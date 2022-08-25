require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:operation) { Fabricate(:operation) }

  before do
    allow(subject).to receive(:fetch_token).and_return(token)
  end

  describe '#operation:cancel' do
    it 'fails if the operation cannot be found' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(nil)

      expect { subject.send('operation:cancel', 1) }
        .to raise_error('Operation #1 not found')
    end

    it 'sets the cancelled flag on the operation' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(operation)

      expect(operation).to receive(:update!).with(cancelled: true)

      subject.send('operation:cancel', 1)
    end
  end

  describe '#operation:log' do
    it 'fails if the operation cannot be found' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(nil)

      expect { subject.send('operation:connect', 1) }
        .to raise_error('Operation #1 not found')
    end

    it 'connects to a running operation' do
      op = Fabricate(:operation, status: 'running', type: 'restart')
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)
      subject.send('operation:connect', op.id.to_s)
    end

    it 'connects to a queued operation' do
      op = Fabricate(:operation, status: 'queued', type: 'restart')
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)
      subject.send('operation:connect', op.id.to_s)
    end

    it 'does not connect to a failed operation' do
      op = Fabricate(:operation, status: 'failed')
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect { subject.send('operation:connect', op.id.to_s) }
        .to raise_error(Thor::Error, /Only currently running operations/)
    end

    it 'does not connect to a succeeded operation' do
      op = Fabricate(:operation, status: 'succeeded')
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect { subject.send('operation:connect', op.id.to_s) }
        .to raise_error(Thor::Error, /Only currently running operations/)
    end
  end
end
