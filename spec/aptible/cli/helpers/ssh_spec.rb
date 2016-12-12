require 'spec_helper'

describe Aptible::CLI::Helpers::Ssh do
  let!(:work_dir) { Dir.mktmpdir }
  after { FileUtils.remove_entry work_dir }
  around { |example| ClimateControl.modify(HOME: work_dir) { example.run } }

  subject { Class.new.send(:include, described_class).new }

  let(:ssh_dir) { File.join(work_dir, '.aptible', 'ssh') }
  let(:config_file) { File.join(ssh_dir, 'config') }
  let(:private_key_file) { File.join(ssh_dir, 'id_rsa') }
  let(:public_key_file) { "#{private_key_file}.pub" }

  describe '#ensure_ssh_dir!' do
    it 'creates the directory' do
      subject.send(:ensure_ssh_dir!)
      expect(Dir.exist?(ssh_dir)).to be_truthy
    end

    it 'works if the directory already exists' do
      subject.send(:ensure_ssh_dir!)
      subject.send(:ensure_ssh_dir!)
    end
  end

  describe '#ensure_config!' do
    before { subject.send(:ensure_ssh_dir!) }

    it 'creates the config file' do
      subject.send(:ensure_config!)
      expect(File.exist?(config_file)).to be_truthy
    end
  end

  describe '#ensure_key!' do
    before { subject.send(:ensure_ssh_dir!) }

    it 'creates the key if it does not exist' do
      subject.send(:ensure_key!)

      expect(File.exist?(private_key_file)).to be_truthy
      expect(File.exist?(public_key_file)).to be_truthy
    end

    it 'does not recreate the key if it already exists' do
      subject.send(:ensure_key!)
      k1 = File.read(private_key_file)
      subject.send(:ensure_key!)
      k2 = File.read(private_key_file)

      expect(k2).to eq(k1)
    end

    it 'recreates the key if either part is missing' do
      subject.send(:ensure_key!)
      k1 = File.read(private_key_file)
      File.delete(private_key_file)

      subject.send(:ensure_key!)
      k2 = File.read(private_key_file)
      File.delete(public_key_file)

      subject.send(:ensure_key!)
      k3 = File.read(private_key_file)

      expect(k2).not_to eq(k1)
      expect(k3).not_to eq(k2)
    end
  end

  describe '#with_ssh_cmd' do
    it 'delegates and yields usable SSH parameters' do
      operation = double('operation')
      connection = double('connection')

      expect(operation).to receive(:with_ssh_cmd).with(private_key_file)
        .and_yield(['some-ssh'], connection)

      has_yielded = false

      subject.with_ssh_cmd(operation) do |cmd, c|
        expect(cmd).to include('some-ssh')
        expect(cmd).to include(config_file)
        expect(c).to be(connection)
        has_yielded = true
      end

      expect(has_yielded).to be_truthy
    end
  end
end
