require 'spec_helper'

describe Aptible::CLI::Helpers::Ssh do
  let!(:work_dir) { Dir.mktmpdir }
  after { FileUtils.remove_entry work_dir }
  around { |example| ClimateControl.modify(HOME: work_dir) { example.run } }

  subject { Class.new.send(:include, described_class).new }

  let(:private_key_file) { File.join(work_dir, '.aptible', 'ssh', 'id_rsa') }
  let(:public_key_file) { "#{private_key_file}.pub" }

  describe '#ensure_key!' do
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
end
