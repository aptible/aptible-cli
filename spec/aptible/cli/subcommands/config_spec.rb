require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:account) { Fabricate(:account) }
  let(:app) { Fabricate(:app, account: account) }

  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  before do
    allow(Aptible::Api::App).to receive(:all)
      .with(token: token).and_return([app])
    allow(Aptible::Api::Account).to receive(:all)
      .with(token: token).and_return([account])
  end

  before { allow(subject).to receive(:options) { { app: app.handle } } }
  let(:operation) { Fabricate(:operation, resource: app) }

  describe '#config' do
    before { allow(subject).to receive(:options).and_return(app: app.handle) }

    it 'shows nothing for an unconfigured app' do
      subject.send('config')
      expect(captured_output_text).to eq('')
      expect(captured_output_json).to match_array([])
    end

    it 'shows an empty configuration' do
      app.current_configuration = Fabricate(:configuration, app: app)
      subject.send('config')
      expect(captured_output_text).to eq('')
      expect(captured_output_json).to match_array([])
    end

    it 'should show environment variables' do
      app.current_configuration = Fabricate(
        :configuration, app: app, env: { 'FOO' => 'BAR', 'QUX' => 'two words' }
      )
      subject.send('config')

      expect(captured_output_text).to match(/FOO=BAR/)
      expect(captured_output_text).to match(/QUX=two\\ words/)

      expected = [
        {
          'key' => 'FOO', 'value' => 'BAR',
          'shell_export' => 'FOO=BAR'
        },
        {
          'key' => 'QUX', 'value' => 'two words',
          'shell_export' => 'QUX=two\\ words'
        }
      ]

      expect(captured_output_json).to match_array(expected)
    end
  end

  describe '#config:set' do
    it 'sets environment variables' do
      expect(app).to receive(:create_operation!)
        .with(type: 'configure', env: { 'FOO' => 'BAR' })
        .and_return(operation)

      expect(subject).to receive(:attach_to_operation_logs)
        .with(operation)

      subject.send('config:set', 'FOO=BAR')
    end

    it 'rejects environment variables that start with -' do
      expect { subject.send('config:set', '-foo=bar') }
        .to raise_error(/invalid argument/im)
    end
  end

  describe '#config:rm' do
    it 'unsets environment variables' do
      expect(app).to receive(:create_operation!)
        .with(type: 'configure', env: { 'FOO' => '' })
        .and_return(operation)

      expect(subject).to receive(:attach_to_operation_logs)
        .with(operation)

      subject.send('config:unset', 'FOO')
    end

    it 'rejects environment variables that start with -' do
      expect { subject.send('config:rm', '-foo') }
        .to raise_error(/invalid argument/im)
    end
  end
end
