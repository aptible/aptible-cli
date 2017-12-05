require 'spec_helper'

describe Aptible::CLI do
  describe described_class::TtyLogFormatter do
    subject do
      Logger.new(File.open(File::NULL, 'w')).tap do |l|
        l.formatter = described_class.new
      end
    end

    it 'formats DEBUG' do
      subject.debug 'foo'
    end

    it 'formats INFO' do
      subject.info 'foo'
    end

    it 'formats WARN' do
      subject.warn 'foo'
    end

    it 'formats ERROR' do
      subject.error 'foo'
    end

    it 'formats FATAL' do
      subject.fatal 'foo'
    end
  end
end
