require 'spec_helper'

describe Aptible::CLI::Helpers::Operation do
  subject { Class.new.send(:include, described_class).new }

  describe '#prettify_operation' do
    it 'works for app operations' do
      op = Fabricate(:operation, id: 123, type: 'deploy', status: 'running',
                                 resource: Fabricate(:app, handle: 'myapp'))

      expect(subject.prettify_operation(op))
        .to eq('running deploy #123 on myapp')
    end

    it 'works for backup operations' do
      op = Fabricate(:operation, id: 123, type: 'restore', status: 'queued',
                                 resource: Fabricate(:backup))

      expect(subject.prettify_operation(op))
        .to eq('queued restore #123')
    end

    it 'will error when operation is not succeeded' do
      op = Fabricate(:operation, id: 123, type: 'restore', status: 'queued',
                     resource: Fabricate(:backup))

      expect(subject.prettify_operation(op))
        .to include('Unable to retrieve operation logs. You can view these logs when the operation is complete.')
    end

    it 'will error when operation logs endpoint errors' do
      op = Fabricate(:operation, id: 123, type: 'restore', status: 'finished',
                     resource: Fabricate(:backup))

      expect(subject.prettify_operation(op))
        .to include('queued restore #123')
    end

    it 'will redirect when operation logs endpoint succeeds and print logs' do
      op = Fabricate(:operation, id: 123, type: 'restore', status: 'queued',
                     resource: Fabricate(:backup))

      expect(subject.prettify_operation(op))
        .to include('queued restore #123')
    end
  end
end
