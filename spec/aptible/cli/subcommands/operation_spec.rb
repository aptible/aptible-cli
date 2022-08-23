require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { 'some-token' }
  let(:operation) { Fabricate(:operation) }
  let(:mock_s3_response) do
    instance_double(Net::HTTPResponse, body: 'Mock logs')
  end

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
  describe '#operation:logs' do
    it 'sends operation logs request when subcommand sent successfully' do
      operation_id = SecureRandom.uuid
      expect(Aptible::Api::Operation).to receive(:find).with(1, token: token)
        .and_return(Fabricate(
                      :operation, status: 'succeeded', id: operation_id
        ))

      # stub out operations call
      response = Net::HTTPSuccess.new(1.0, '301', 'OK')
      response.add_field('location', 'https://aptible.com/not-real')
      expect_any_instance_of(Net::HTTP)
        .to receive(:request)
        .with(an_instance_of(Net::HTTP::Get))
        .and_return(response)

      # stub out s3 call
      s3_response = Net::HTTPSuccess.new(1.0, '200', 'OK')
      s3_response.body = response
      expect_any_instance_of(Net::HTTP)
        .to receive(:request)
        .with(an_instance_of(Net::HTTP::Get))
        .and_return(mock_s3_response)

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
        .to raise_error('Error - You can view the logs when operation'\
                        'is complete.')
    end
    it 'errors when operation not found and errored on deploy API' do
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
        .to raise_error('Unable to retrieve operation logs with 301.')
    end
  end
end
