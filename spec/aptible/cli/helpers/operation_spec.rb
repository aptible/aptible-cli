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
  end
end
