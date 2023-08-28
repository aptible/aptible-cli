require 'spec_helper'

describe Aptible::CLI::Agent do
  include Aptible::CLI::Helpers::DateHelpers

  let(:token) { double('token') }

  before do
    allow(subject).to receive(:ask)
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:fetch_token) { token }
  end

  let(:handle) { 'foobar' }
  let(:stack) { Fabricate(:stack, internal_domain: 'aptible.in') }
  let(:account) { Fabricate(:account, stack: stack) }
  let(:database) { Fabricate(:database, handle: handle, account: account) }
  let(:staging) { Fabricate(:account, handle: 'staging') }
  let(:prod) { Fabricate(:account, handle: 'production') }
  let(:window_start) { '2073-09-05T22:00:00.000Z' }
  let(:window_end) { '2073-09-05T23:00:00.000Z' }
  let(:maintenance_dbs) do
    [
      [staging, 'staging-redis-db', [window_start, window_end]],
      [staging, 'staging-postgres-db', nil],
      [prod, 'prod-elsearch-db', [window_start, window_end]],
      [prod, 'prod-postgres-db', nil]
    ].map do |a, h, m|
      Fabricate(
        :maintenance_database,
        account: a,
        handle: h,
        maintenance_deadline: m
      )
    end
  end
  let(:maintenance_apps) do
    [
      [staging, 'staging-app-1', [window_start, window_end]],
      [staging, 'staging-app-2', nil],
      [prod, 'prod-app-1', [window_start, window_end]],
      [prod, 'prod-app-2', nil]
    ].map do |a, h, m|
      Fabricate(
        :maintenance_app,
        account: a,
        handle: h,
        maintenance_deadline: m
      )
    end
  end

  describe '#maintenance:dbs' do
    before do
      token = 'the-token'
      allow(subject).to receive(:fetch_token) { token }
      allow(Aptible::Api::Account).to receive(:all)
        .with(token: token)
        .and_return([staging, prod])
      allow(Aptible::Api::MaintenanceDatabase).to receive(:all)
        .with(token: token)
        .and_return(maintenance_dbs)
    end

    context 'when no account is specified' do
      it 'prints out the grouped database handles for all accounts' do
        subject.send('maintenance:dbs')

        expect(captured_output_text).to include('=== staging')
        expect(captured_output_text).to include('staging-redis-db')
        expect(captured_output_text).to include('2073-09-05 22:00:00 UTC')
        expect(captured_output_text).to include('2073-09-05 23:00:00 UTC')
        expect(captured_output_text).not_to include('staging-postgres-db')

        expect(captured_output_text).to include('=== production')
        expect(captured_output_text).to include('prod-elsearch-db')
        expect(captured_output_text).to include('2073-09-05 22:00:00 UTC')
        expect(captured_output_text).to include('2073-09-05 23:00:00 UTC')
        expect(captured_output_text).not_to include('prod-postgres-db')

        expect(captured_output_json.to_s)
          .to include(
            'aptible db:restart staging-redis-db --environment staging'
          )
        expect(captured_output_json.to_s)
          .to include(
            'aptible db:restart prod-elsearch-db --environment production'
          )
      end
    end

    context 'when a valid account is specified' do
      it 'prints out the database handles for the account' do
        subject.options = { environment: 'staging' }
        subject.send('maintenance:dbs')

        expect(captured_output_text).to include('=== staging')
        expect(captured_output_text).to include('staging-redis-db')
        expect(captured_output_text).to include('2073-09-05 22:00:00 UTC')
        expect(captured_output_text).to include('2073-09-05 23:00:00 UTC')
        expect(captured_output_text).not_to include('staging-postgres-db')

        expect(captured_output_text).not_to include('=== production')
        expect(captured_output_text).not_to include('prod-elsearch-db')
        expect(captured_output_text).not_to include('prod-postgres-db')

        expect(captured_output_json.to_s)
          .to include(
            'aptible db:restart staging-redis-db --environment staging'
          )
      end
    end

    context 'when an invalid account is specified' do
      it 'prints out an error' do
        subject.options = { environment: 'foo' }
        expect { subject.send('maintenance:dbs') }
          .to raise_error('Specified account does not exist')
      end
    end
  end
  describe '#maintenance:apps' do
    before do
      token = 'the-token'
      allow(subject).to receive(:fetch_token) { token }
      allow(Aptible::Api::Account).to receive(:all).with(token: token)
        .and_return([staging, prod])
      allow(Aptible::Api::MaintenanceApp).to receive(:all).with(token: token)
        .and_return(maintenance_apps)
    end

    context 'when no account is specified' do
      it 'prints out the grouped app handles for all accounts' do
        subject.send('maintenance:apps')

        expect(captured_output_text).to include('=== staging')
        expect(captured_output_text).to include('staging-app-1')
        expect(captured_output_text).to include('2073-09-05 22:00:00 UTC')
        expect(captured_output_text).to include('2073-09-05 23:00:00 UTC')
        expect(captured_output_text).not_to include('staging-app-2')

        expect(captured_output_text).to include('=== production')
        expect(captured_output_text).to include('prod-app-1')
        expect(captured_output_text).to include('2073-09-05 22:00:00 UTC')
        expect(captured_output_text).to include('2073-09-05 23:00:00 UTC')
        expect(captured_output_text).not_to include('prod-app-2')

        expect(captured_output_json.to_s)
          .to include(
            'aptible restart --app staging-app-1 --environment staging'
          )
        expect(captured_output_json.to_s)
          .to include(
            'aptible restart --app prod-app-1 --environment production'
          )
      end
    end

    context 'when a valid account is specified' do
      it 'prints out the app handles for the account' do
        subject.options = { environment: 'staging' }
        subject.send('maintenance:apps')

        expect(captured_output_text).to include('=== staging')
        expect(captured_output_text).to include('staging-app-1')
        expect(captured_output_text).to include('2073-09-05 22:00:00 UTC')
        expect(captured_output_text).to include('2073-09-05 23:00:00 UTC')
        expect(captured_output_text).not_to include('staging-app-2')

        expect(captured_output_text).not_to include('=== production')
        expect(captured_output_text).not_to include('prod-app-1')
        expect(captured_output_text).not_to include('prod-app-2')

        expect(captured_output_json.to_s)
          .to include(
            'aptible restart --app staging-app-1 --environment staging'
          )
      end
    end

    context 'when an invalid account is specified' do
      it 'prints out an error' do
        subject.options = { environment: 'foo' }
        expect { subject.send('maintenance:apps') }
          .to raise_error('Specified account does not exist')
      end
    end
  end
end
