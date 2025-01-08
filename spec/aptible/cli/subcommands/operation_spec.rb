require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:operation) { Fabricate(:operation) }
  let(:net_http_double) { double('Net::HTTP') }
  let(:net_http_get_double) { double('Net::HTTP::Get') }

  before do
    allow(subject).to receive(:fetch_token).and_return(token)
  end

  describe '#operation:cancel' do
    it 'fails if the operation cannot be found' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(nil)

      expect { subject.send('operation:cancel', 1) }
        .to raise_error('Operation #1 not found')
    end

    it 'sets the cancelled flag on the operation' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(operation)

      expect(operation).to receive(:update!).with(cancelled: true)

      subject.send('operation:cancel', 1)
    end
  end

  describe '#operation:follow' do
    it 'fails if the operation cannot be found' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(nil)

      expect { subject.send('operation:follow', 1) }
        .to raise_error('Operation #1 not found')
    end

    it 'connects to a running operation' do
      op = Fabricate(:operation, status: 'running', type: 'restart')
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)
      subject.send('operation:follow', op.id.to_s)
    end

    it 'connects to a queued operation' do
      op = Fabricate(:operation, status: 'queued', type: 'restart')
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)
      subject.send('operation:follow', op.id.to_s)
    end

    it 'does not connect to a failed operation' do
      id = 34
      status = 'failed'
      op = Fabricate(:operation, id: id, status: status)
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect { subject.send('operation:follow', op.id.to_s) }
        .to raise_error(Thor::Error, /aptible operation:logs #{id}/)
    end

    it 'does not connect to a succeeded operation' do
      id = 43
      status = 'succeeded'
      op = Fabricate(:operation, id: id, status: status)
      expect(Aptible::Api::Operation).to receive(:find)
        .with(op.id.to_s, token: token).and_return(op)

      expect { subject.send('operation:follow', op.id.to_s) }
        .to raise_error(Thor::Error, /aptible operation:logs #{id}/)
    end
  end

  describe '#operation:logs' do
    it 'sends operation logs request when subcommand sent' do
      operation_id = SecureRandom.uuid
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(Fabricate(
                      :operation, status: 'succeeded', id: operation_id
        ))

      # stub out operations call
      response = instance_double(Net::HTTPResponse, body: 'https://s3.aptible.com/not-real/s3')

      # stub out s3 call
      s3_response = instance_double(Net::HTTPResponse, body: 'Mock logs')

      allow(Net::HTTP).to receive(:new).twice do |_, _, _|
        net_http_double
      end
      expect(response).to receive(:code).and_return('200')
      expect(s3_response).to receive(:code).and_return('200')
      expect(net_http_double).to receive(:use_ssl=).twice
      expect(net_http_double).to receive(:request).twice do |request|
        if request.path == "/operations/#{operation_id}/logs"
          response
        elsif request.path == '/not-real/s3'
          s3_response
        end
      end

      subject.send('operation:logs', 1)
    end

    it 'errors when operation is not found' do
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(nil)

      expect { subject.send('operation:logs', 1) }
        .to raise_error('Operation #1 not found')
    end
    it 'errors when operation is not status expected' do
      operation_id = SecureRandom.uuid
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(Fabricate(:operation, status: 'queued', id: operation_id))

      expect { subject.send('operation:logs', 1) }
        .to raise_error('Error - You can view the logs when operation '\
                        'is complete.')
    end
    it 'errors when operation logs are not found' do
      operation_id = SecureRandom.uuid
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(
          Fabricate(:operation, status: 'succeeded', id: operation_id)
        )

      # stub out operations call
      response = Net::HTTPSuccess.new(1.0, '404', 'Not Found')
      expect_any_instance_of(Net::HTTP)
        .to receive(:request)
        .with(an_instance_of(Net::HTTP::Get))
        .and_return(response)

      expect { subject.send('operation:logs', 1) }
        .to raise_error('Unable to retrieve the operation\'s logs. '\
          'If the issue persists please contact support for assistance, ' \
          "or view them at https://app.aptible.com/operations/#{operation_id}")
    end
    it 'errors when body is empty' do
      operation_id = SecureRandom.uuid
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(Fabricate(
                      :operation, status: 'succeeded', id: operation_id
        ))

      # stub out operations call
      response = instance_double(Net::HTTPResponse, body: nil)

      allow(Net::HTTP).to receive(:new) do |_, _, _|
        net_http_double
      end
      expect(response).to receive(:code).and_return('200')
      expect(net_http_double).to receive(:use_ssl=)
      expect(net_http_double).to receive(:request).and_return(response)

      expect { subject.send('operation:logs', 1) }
        .to raise_error('Unable to retrieve the operation\'s logs. '\
          'If the issue persists please contact support for assistance, ' \
          "or view them at https://app.aptible.com/operations/#{operation_id}")
    end
    it 'errors when s3 itself returns an error code' do
      operation_id = SecureRandom.uuid
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(Fabricate(
                      :operation, status: 'succeeded', id: operation_id
        ))

      # stub out operations call
      response = instance_double(Net::HTTPResponse, body: 'https://s3.aptible.com/not-real/s3')

      # stub out s3 call (to fail)
      expect(response).to receive(:code).and_return('200')
      s3_response = Net::HTTPSuccess.new(1.0, '404', 'Not Found')

      allow(Net::HTTP).to receive(:new).twice do |_, _, _|
        net_http_double
      end
      expect(net_http_double).to receive(:use_ssl=).twice
      expect(net_http_double).to receive(:request).twice do |request|
        if request.path == "/operations/#{operation_id}/logs"
          response
        elsif request.path == '/not-real/s3'
          s3_response
        end
      end

      expect { subject.send('operation:logs', 1) }
        .to raise_error('Unable to retrieve operation logs, '\
                        'S3 returned response code 404. '\
                        'If the issue persists please contact support for '\
                        'assistance.')
    end
  end
end
