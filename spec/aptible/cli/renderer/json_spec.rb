require 'spec_helper'

describe Aptible::CLI::Renderer::Json do
  subject { described_class.new }

  let(:root) { Aptible::CLI::Formatter::Root.new }

  it 'renders an object' do
    root.object { |n| n.value('foo', 'bar') }
    expect(JSON.parse(subject.render(root))).to eq('foo' => 'bar')
  end

  it 'renders a list' do
    root.list do |l|
      l.value('foo')
      l.value('bar')
    end
    expect(JSON.parse(subject.render(root))).to eq(%w(foo bar))
  end

  it 'ignores keyed_list' do
    root.keyed_list('foo') do |l|
      l.object do |n|
        n.value('foo', 'bar')
        n.value('qux', 'baz')
      end
    end

    expect(JSON.parse(subject.render(root)))
      .to eq([{ 'foo' => 'bar', 'qux' => 'baz' }])
  end

  it 'ignores grouped_keyed_list' do
    root.grouped_keyed_list('foo', 'qux') do |l|
      l.object do |n|
        n.value('foo', 'bar')
        n.value('qux', 'baz')
      end
    end

    expect(JSON.parse(subject.render(root)))
      .to eq([{ 'foo' => 'bar', 'qux' => 'baz' }])
  end

  it 'ignores keyed_object' do
    root.keyed_object('foo') { |n| n.value('foo', 'bar') }
    expect(JSON.parse(subject.render(root))).to eq('foo' => 'bar')
  end

  it 'nests objects' do
    root.object do |n|
      n.object('foo') { |nn| nn.value('bar', 'qux') }
    end
    expect(JSON.parse(subject.render(root))).to eq('foo' => { 'bar' => 'qux' })
  end

  it 'nests lists' do
    root.list do |n|
      n.list { |nn| nn.value('bar') }
    end
    expect(JSON.parse(subject.render(root))).to eq([%w(bar)])
  end
end
