require 'spec_helper'

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }

  let!(:foo_certs) { [Fabricate(:cert), Fabricate(:cert)] }
  let!(:bar_certs) { [Fabricate(:cert)] }
  let!(:foo_account) do
    Fabricate(:account, certificates: foo_certs, handle: 'foo')
  end
  let!(:bar_account) do
    Fabricate(:account, certificates: bar_certs, handle: 'bar')
  end

  describe '#certs' do
    include_context 'with output'

    before do
      allow(Aptible::Api::Certificate).to receive(:all) do
        [Fabricate(:cert)]
      end
      allow(subject).to receive(:options) { {} }
      allow(Aptible::Api::Account).to receive(:all) do
        [foo_account, bar_account]
      end
    end

    it 'prints all certificates for all environments' do
      subject.send('certs')

      expect(output).to eq <<-eos
=== foo
#{foo_certs[0].id}: '*.example.com', Justice League, valid 2015-08-20 - 2017-08-20
#{foo_certs[1].id}: '*.example.com', Justice League, valid 2015-08-20 - 2017-08-20

=== bar
#{bar_certs[0].id}: '*.example.com', Justice League, valid 2015-08-20 - 2017-08-20

      eos
    end

    context 'with an environment specified' do
      before do
        allow(subject).to receive(:options) { { environment: 'foo' } }
        expect(subject).to receive(:environment_from_handle)
          .with('foo')
          .and_return(foo_account)
      end
      it 'should print all certificates for environment' do
        subject.send('certs')

        expect(output).to eq <<-eos
=== foo
#{foo_certs[0].id}: '*.example.com', Justice League, valid 2015-08-20 - 2017-08-20
#{foo_certs[1].id}: '*.example.com', Justice League, valid 2015-08-20 - 2017-08-20

        eos
      end
    end
  end
end
