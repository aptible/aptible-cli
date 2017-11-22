require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:app) { Fabricate(:app) }
  let(:operation) { Fabricate(:operation, resource: app) }
  before { allow(subject).to receive(:ensure_app).and_return(app) }

  describe '#rebuild' do
    it 'rebuilds the app' do
      expect(app).to receive(:create_operation!)
        .with(type: 'rebuild').and_return(operation)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)

      subject.send('rebuild')
    end
  end
end
