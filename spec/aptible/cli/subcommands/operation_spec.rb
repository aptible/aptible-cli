require 'spec_helper'

def fmt_time(time)
  time.strftime('%Y-%m-%d %H:%M:%S %z')
end

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:operation) { Fabricate(:operation) }
  let(:account) { Fabricate(:account, handle: 'stuff') }
  let!(:a) { Fabricate(:app, handle: 'httpd', account: account) }

  # App operations
  let!(:a_deploy) do
    Fabricate(:operation, type: 'deploy',
                          status: 'succeeded',
                          git_ref: SecureRandom.hex(20),
                          app: a)
  end
  let!(:a_restart) { Fabricate(:operation, type: 'restart', app: a) }
  let!(:a_configure) do
    Fabricate(:operation, type: 'configure', app: a,
                          env: { 'FOO' => 'bar', 'BAZ' => 'bat' })
  end
  let!(:a_rebuild) { Fabricate(:operation, type: 'rebuild', app: a) }
  let!(:a_restart) { Fabricate(:operation, type: 'restart', app: a) }
  let!(:a_execute) do
    Fabricate(:operation, type: 'execute', app: a,
                          command: '/bin/sh')
  end
  let!(:a_logs) { Fabricate(:operation, type: 'logs', app: a) }

  let(:a_scale) do
    Fabricate(:operation, type: 'scale')
  end

  let(:as) { Fabricate(:service, app: a, process_type: 'web') }

  # Database Operations
  let(:d_provision) { Fabricate(:operation, type: 'provision') }
  let(:d_restart) { Fabricate(:operation, type: 'restart') }
  let(:d_reload) { Fabricate(:operation, type: 'reload') }
  let(:d_clone) { Fabricate(:operation, type: 'clone') }
  let(:d_replicate) { Fabricate(:operation, type: 'replicate') }
  let(:d_replicate_logical) do
    Fabricate(:operation, type: 'replicate_logical')
  end
  let(:d_backup) { Fabricate(:operation, type: 'backup') }
  let(:d_tunnel) { Fabricate(:operation, type: 'tunnel') }
  let(:d_logs) { Fabricate(:operation, type: 'logs') }

  # Database Operations (rare)
  let(:d_restart_recreate) do
    Fabricate(:operation, type: 'restart_recreate')
  end
  let(:d_recover) { Fabricate(:operation, type: 'recover') }
  let(:d_recover_recreate) do
    Fabricate(:operation, type: 'recovery_recreate')
  end
  let(:d_evacuate) { Fabricate(:operation, type: 'evacuate') }

  let(:d) { Fabricate(:database, handle: 'psql', account: account) }

  before do
    allow(subject).to receive(:fetch_token).and_return(token)
  end

  describe '#operation:list' do
    it 'supports App operations' do
      expect(Aptible::Api::App).to receive(:all)
        .with(token: token)
        .and_return([a])

      expected_json = [
        {
          'created_at'    => fmt_time(a_logs.created_at),
          'description'   => "#{a_logs.id}: " \
                             "#{fmt_time(a_logs.created_at)}, " \
                             "StubApp #{a_logs.type} " \
                             "#{a_logs.status}, " \
                             "#{a_logs.user_email}",
          'id'            => a_logs.id,
          'operation'     => a_logs.type,
          'status'        => a_logs.status,
          'user_email'    => a_logs.user_email,
          'resource_type' => 'StubApp'
        },
        {
          'command'       => a_execute.command,
          'created_at'    => fmt_time(a_execute.created_at),
          'description'   => "#{a_execute.id}: " \
                             "#{fmt_time(a_execute.created_at)}, " \
                             "StubApp #{a_execute.type} " \
                             "#{a_execute.status}, " \
                             "#{a_execute.user_email}, " \
                             "command: \"#{a_execute.command}\"",
          'id'            => a_execute.id,
          'operation'     => a_execute.type,
          'status'        => a_execute.status,
          'user_email'    => a_execute.user_email,
          'resource_type' => 'StubApp'
        },
        {
          'created_at'    => fmt_time(a_rebuild.created_at),
          'description'   => "#{a_rebuild.id}: " \
                             "#{fmt_time(a_rebuild.created_at)}, " \
                             "StubApp #{a_rebuild.type} " \
                             "#{a_rebuild.status}, " \
                             "#{a_rebuild.user_email}",
          'git_ref'       => a_rebuild.git_ref,
          'id'            => a_rebuild.id,
          'operation'     => a_rebuild.type,
          'status'        => a_rebuild.status,
          'user_email'    => a_rebuild.user_email,
          'resource_type' => 'StubApp'
        },
        {
          'created_at'    => fmt_time(a_configure.created_at),
          'description'   => "#{a_configure.id}: " \
                             "#{fmt_time(a_configure.created_at)}, " \
                             "StubApp #{a_configure.type} " \
                             "#{a_configure.status}, " \
                             "#{a_configure.user_email}, " \
                             'env: FOO BAZ',
          'id'            => a_configure.id,
          'operation'     => a_configure.type,
          'status'        => a_configure.status,
          'user_email'    => a_configure.user_email,
          'env'           => { 'BAZ' => 'bat', 'FOO' => 'bar' },
          'resource_type' => 'StubApp'
        },
        {
          'created_at'    => fmt_time(a_restart.created_at),
          'description'   => "#{a_restart.id}: " \
                             "#{fmt_time(a_restart.created_at)}, " \
                             "StubApp #{a_restart.type} " \
                             "#{a_restart.status}, " \
                             "#{a_restart.user_email}",
          'id'            => a_restart.id,
          'operation'     => a_restart.type,
          'status'        => a_restart.status,
          'user_email'    => a_restart.user_email,
          'resource_type' => 'StubApp'
        },
        {
          'created_at'    => a_deploy.created_at
                                     .strftime('%Y-%m-%d %H:%M:%S %z'),
          'description'   => "#{a_deploy.id}: " \
                             "#{fmt_time(a_deploy.created_at)}, " \
                             "StubApp #{a_deploy.type} " \
                             "#{a_deploy.status}, " \
                             "#{a_deploy.user_email}",
          'git_ref'       => a_deploy.git_ref,
          'id'            => a_deploy.id,
          'operation'     => a_deploy.type,
          'status'        => a_deploy.status,
          'user_email'    => a_deploy.user_email,
          'resource_type' => 'StubApp'
        }
      ]

      subject.options = { app: a.handle, max_age: '1w' }
      subject.send('operation:list')

      expect(captured_output_text.split("\n").size).to eq(6)
      expect(captured_output_json).to eq(expected_json)
    end

    it 'lists all relevent operations for a database' do
      # expect(captured_output_text.split("\n").size).to eq(9)
    end

    it 'lists all relevent operations for an app' do
      # expect(captured_output_text.split("\n").size).to eq(9)
    end

    it 'describes running operations in the present tense' do
      false
    end

    it 'describes completed operations in the past tense' do
      false
    end

    it 'can list App operations' do
      false
    end

    it 'can list Database operations' do
      false
    end
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
end
