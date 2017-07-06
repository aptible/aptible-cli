require 'spec_helper'

describe Aptible::CLI::Helpers::Token do
  around do |example|
    Dir.mktmpdir { |home| ClimateControl.modify(HOME: home) { example.run } }
  end

  subject { Class.new.send(:include, described_class).new }

  describe '#save_token / #fetch_token' do
    it 'reads back a token it saved' do
      subject.save_token('foo')
      expect(subject.fetch_token).to eq('foo')
    end
  end

  context 'permissions' do
    before { skip 'Windows' if Gem.win_platform? }

    describe '#save_token' do
      it 'creates the token_file with mode 600' do
        subject.save_token('foo')
        expect(format('%o', File.stat(subject.token_file).mode))
          .to eq('100600')
      end
    end

    describe '#current_token_hash' do
      it 'updates the token_file to mode 600' do
        subject.save_token('foo')
        File.chmod(0o644, subject.token_file)
        expect(format('%o', File.stat(subject.token_file).mode))
          .to eq('100644')

        subject.current_token_hash
        expect(format('%o', File.stat(subject.token_file).mode))
          .to eq('100600')
      end
    end
  end
end
