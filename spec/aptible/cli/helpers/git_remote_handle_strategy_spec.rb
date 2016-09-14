require 'spec_helper'

describe Aptible::CLI::Helpers::App::GitRemoteHandleStrategy do
  around do |example|
    Dir.mktmpdir do |work_dir|
      Dir.chdir(work_dir) { example.run }
    end
  end

  context 'with git repo' do
    before { `git init` }

    context 'with aptible remote' do
      before do
        `git remote add aptible git@beta.aptible.com:some-env/some-app.git`
        `git remote add prod git@beta.aptible.com:prod-env/prod-app.git`
      end

      it 'defaults to the Aptible remote' do
        s = described_class.new({})
        expect(s.app_handle).to eq('some-app')
        expect(s.env_handle).to eq('some-env')
        expect(s.usable?).to be_truthy
      end

      it 'allows explicitly passing a remote' do
        s = described_class.new(remote: 'prod')
        expect(s.app_handle).to eq('prod-app')
        expect(s.env_handle).to eq('prod-env')
        expect(s.usable?).to be_truthy
      end

      it 'accepts a remote from the environment' do
        ClimateControl.modify APTIBLE_REMOTE: 'prod' do
          s = described_class.new(remote: 'prod')
          expect(s.app_handle).to eq('prod-app')
        end
      end

      it 'is not usable when the remote does not exist' do
        s = described_class.new(remote: 'foobar')
        expect(s.usable?).to be_falsey
      end

      it 'outputs the remote when explaining' do
        s = described_class.new(remote: 'prod')
        expect(s.explain).to match(/derived from git remote prod/)
      end
    end
  end

  it 'is not usable outside of a git repo' do
    s = described_class.new({})
    expect(s.usable?).to be_falsey
  end
end
