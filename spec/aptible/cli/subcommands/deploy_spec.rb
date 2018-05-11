require 'spec_helper'

describe Aptible::CLI::Agent do
  let!(:account) { Fabricate(:account, handle: 'foobar') }
  let!(:app) { Fabricate(:app, handle: 'hello', account: account) }
  let(:operation) { Fabricate(:operation) }

  describe '#deploy' do
    before do
      allow(Aptible::Api::App).to receive(:all) { [app] }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
      allow(subject).to receive(:fetch_token) { double'token' }
    end

    context 'with app' do
      let(:base_options) { { app: app.handle, environment: account.handle } }

      def stub_options(**opts)
        allow(subject).to receive(:options).and_return(base_options.merge(opts))
      end

      it 'deploys' do
        stub_options

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy').and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy
      end

      it 'deploys a committish' do
        stub_options(git_commitish: 'foobar')

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', git_ref: 'foobar').and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy
      end

      it 'deploys a Docker image' do
        stub_options(docker_image: 'foobar')

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', env: { 'APTIBLE_DOCKER_IMAGE' => 'foobar' })
          .and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy
      end

      it 'deploys with credentials' do
        stub_options(
          private_registry_email: 'foo',
          private_registry_username: 'bar',
          private_registry_password: 'qux'
        )

        env = {
          'APTIBLE_PRIVATE_REGISTRY_EMAIL' => 'foo',
          'APTIBLE_PRIVATE_REGISTRY_USERNAME' => 'bar',
          'APTIBLE_PRIVATE_REGISTRY_PASSWORD' => 'qux'
        }

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', env: env)
          .and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy
      end

      it 'detaches a git repo' do
        stub_options(git_detach: true)

        ref = '0000000000000000000000000000000000000000'

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', git_ref: ref)
          .and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy
      end

      it 'fails if detaching the git repo and providing a commitish' do
        stub_options(git_commitish: 'foo', git_detach: true)

        expect { subject.deploy }.to raise_error(/are incompatible/im)
      end

      it 'allows setting configuration variables' do
        stub_options

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', env: { 'FOO' => 'bar', 'BAR' => 'qux' })
          .and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy('FOO=bar', 'BAR=qux')
      end

      it 'allows unsetting configuration variables' do
        stub_options

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', env: { 'FOO' => '' })
          .and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy('FOO=')
      end

      it 'rejects arguments with a leading -' do
        stub_options

        expect { subject.deploy('--aptible-docker-image=bar') }
          .to raise_error(/invalid argument/im)
      end

      it 'rejects arguments without =' do
        stub_options

        expect { subject.deploy('foobar') }
          .to raise_error(/invalid argument/im)
      end

      it 'allows redundant command line arguments' do
        stub_options(docker_image: 'foobar')

        expect(app).to receive(:create_operation!)
          .with(type: 'deploy', env: { 'APTIBLE_DOCKER_IMAGE' => 'foobar' })
          .and_return(operation)
        expect(subject).to receive(:attach_to_operation_logs)
          .with(operation)

        subject.deploy('APTIBLE_DOCKER_IMAGE=foobar')
      end

      it 'reject contradictory command line argumnts' do
        stub_options(docker_image: 'foobar')

        expect { subject.deploy('APTIBLE_DOCKER_IMAGE=qux') }
          .to raise_error(/different values/im)
      end

      it 'does not allow deploying nothing on an unprovisioned app' do
        stub_options

        allow(app).to receive(:status) { 'pending' }

        expect { subject.deploy }
          .to raise_error(/either from git.*docker/im)
      end
    end
  end
end
