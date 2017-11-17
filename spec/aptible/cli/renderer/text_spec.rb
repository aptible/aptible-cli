require 'spec_helper'

describe Aptible::CLI::Renderer::Text do
  subject { described_class.new }

  let(:root) { Aptible::CLI::Formatter::Root.new }

  it 'renders an object' do
    root.object { |n| n.value('foo', 'bar') }
    expect(subject.render(root)).to eq("Foo: bar\n")
  end

  it 'renders a list' do
    root.list do |l|
      l.value('foo')
      l.value('bar')
    end
    expect(subject.render(root)).to eq("foo\nbar\n")
  end

  it 'renders the key in a keyed_list' do
    root.keyed_list('foo') do |l|
      l.object do |n|
        n.value('foo', 'bar')
        n.value('qux', 'baz')
      end

      l.object do |n|
        n.value('foo', 'bar2')
        n.value('qux', 'baz2')
      end
    end

    expect(subject.render(root)).to eq("bar\nbar2\n")
  end

  it 'renders the keys in a grouped_keyed_list, with plain grouping' do
    root.grouped_keyed_list('foo', 'qux') do |l|
      l.object do |n|
        n.value('foo', 'bar')
        n.value('qux', 'baz')
      end
      l.object do |n|
        n.value('foo', 'bar')
        n.value('qux', 'baz2')
      end
      l.object do |n|
        n.value('foo', 'bar2')
        n.value('qux', 'baz3')
      end
    end

    expected = [
      '=== bar',
      'baz',
      'baz2',
      '',
      '=== bar2',
      'baz3',
      ''
    ].join("\n")

    expect(subject.render(root)).to eq(expected)
  end

  it 'renders the keys in a grouped_keyed_list, with nested grouping' do
    root.grouped_keyed_list({ 'foo' => 'nest' }, 'qux') do |l|
      l.object do |n|
        n.object('foo') { |nn| nn.value('nest', 'bar') }
        n.value('qux', 'baz')
      end
      l.object do |n|
        n.object('foo') { |nn| nn.value('nest', 'bar') }
        n.value('qux', 'baz2')
      end
      l.object do |n|
        n.object('foo') { |nn| nn.value('nest', 'bar2') }
        n.value('qux', 'baz3')
      end
    end

    expected = [
      '=== bar',
      'baz',
      'baz2',
      '',
      '=== bar2',
      'baz3',
      ''
    ].join("\n")

    expect(subject.render(root)).to eq(expected)
  end

  it 'renders the key in a keyed_object' do
    root.keyed_object('foo') { |n| n.value('foo', 'bar') }
    expect(subject.render(root)).to eq("bar\n")
  end

  it 'renders a plain value' do
    root.value('foo')
    expect(subject.render(root)).to eq("foo\n")
  end

  it 'renders a list of objects' do
    root.list do |l|
      l.object do |n|
        n.value('foo', 'bar1')
        n.value('qux', 'baz1')
      end
      l.object do |n|
        n.value('foo', 'bar2')
        n.value('qux', 'baz2')
      end
      l.object do |n|
        n.value('foo', 'bar3')
        n.value('qux', 'baz3')
      end
    end

    expected = [
      'Foo: bar1',
      'Qux: baz1',
      '',
      'Foo: bar2',
      'Qux: baz2',
      '',
      'Foo: bar3',
      'Qux: baz3',
      ''
    ].join("\n")

    expect(subject.render(root)).to eq(expected)
  end

  it 'capitalizes keys' do
    root.list do |l|
      l.object do |n|
        n.value('this is tls dns and ip', 'foo')
      end
    end

    expected = [
      'This Is TLS DNS And IP: foo',
      ''
    ].join("\n")

    expect(subject.render(root)).to eq(expected)
  end
end
