# frozen_string_literal: true

require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  describe '#aws_accounts' do
    it 'lists external AWS accounts' do
      a1 = Fabricate(:external_aws_account,
                     account_name: 'Dev',
                     aws_account_id: '111111111111',
                     role_arn: 'arn:aws:iam::111111111111:role/' \
                               'DevRole')
      a2 = Fabricate(:external_aws_account,
                     account_name: 'Prod',
                     aws_account_id: '222222222222',
                     role_arn: 'arn:aws:iam::222222222222:role/' \
                               'ProdRole')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token,
              href: '/external_aws_accounts?per_page=5000&no_embed=true')
        .and_return([a1, a2])

      subject.send('aws_accounts')

      # Spot-check a few rendered fields
      expect(captured_output_text).to include("Id: #{a1.id}")
      expect(captured_output_text).to include('Account Name: Dev')
      expect(captured_output_text).to include('Aws Account: 111111111111')
      expect(captured_output_text).to(
        include('Role Arn: arn:aws:iam::111111111111:role/DevRole')
      )

      expect(captured_output_text).to include("Id: #{a2.id}")
      expect(captured_output_text).to include('Account Name: Prod')
      expect(captured_output_text).to include('Aws Account: 222222222222')
      expect(captured_output_text).to(
        include('Role Arn: arn:aws:iam::222222222222:role/ProdRole')
      )
    end

    it 'handles empty list' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token,
              href: '/external_aws_accounts?per_page=5000&no_embed=true')
        .and_return([])

      subject.send('aws_accounts')

      expect(captured_output_text).to eq('')
    end

    it 'renders JSON output and uses JSON href' do
      a1 = Fabricate(:external_aws_account,
                     account_name: 'Dev',
                     aws_account_id: '111111111111',
                     role_arn: 'arn:aws:iam::111111111111:role/DevRole')

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token, href: '/external_aws_accounts')
        .and_return([a1])

      subject.send('aws_accounts')

      json = captured_output_json
      expect(json).to be_a(Array)
      expect(json.first['id']).to eq(a1.id)
      expect(json.first['account_name']).to eq('Dev')
      expect(json.first['aws_account_id']).to eq('111111111111')
      expect(json.first['role_arn']).to(
        eq('arn:aws:iam::111111111111:role/DevRole')
      )
    end
  end

  describe '#aws_accounts:add' do
    it 'creates an external AWS account' do
      created = Fabricate(
        :external_aws_account,
        account_name: 'Staging',
        aws_account_id: '123456789012',
        role_arn: 'arn:aws:iam::123456789012:role/' \
                  'StagingRole',
        discovery_enabled: true,
        discovery_frequency: 'daily',
        aws_region_primary: 'us-east-1'
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        role_arn: 'arn:aws:iam::123456789012:role/StagingRole',
        account_name: 'Staging',
        aws_account_id: '123456789012',
        aws_region_primary: 'us-east-1',
        discovery_enabled: true,
        discovery_frequency: 'daily'
      ).and_return(created)

      subject.options = {
        role_arn: 'arn:aws:iam::123456789012:role/StagingRole',
        account_name: 'Staging',
        aws_account_id: '123456789012',
        aws_region_primary: 'us-east-1',
        discovery_enabled: true,
        discovery_frequency: 'daily'
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include("Id: #{created.id}")
      expect(captured_output_text).to include('Account Name: Staging')
      expect(captured_output_text).to include('Aws Account: 123456789012')
      expect(captured_output_text).to(
        include('Role Arn: arn:aws:iam::123456789012:role/StagingRole')
      )
    end

    it 'creates with minimal options (role_arn only)' do
      created = Fabricate(:external_aws_account,
                          role_arn: 'arn:aws:iam::123456789012:role/' \
                                    'MinRole')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        role_arn: 'arn:aws:iam::123456789012:role/MinRole'
      ).and_return(created)

      subject.options = {
        role_arn: 'arn:aws:iam::123456789012:role/MinRole'
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include("Id: #{created.id}")
      expect(captured_output_text).to(
        include('Role Arn: arn:aws:iam::123456789012:role/MinRole')
      )
    end

    it 'supports --arn alias for --role-arn' do
      created = Fabricate(:external_aws_account,
                          role_arn: 'arn:aws:iam::123456789012:role/' \
                                    'AliasRole')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        role_arn: 'arn:aws:iam::123456789012:role/AliasRole'
      ).and_return(created)

      subject.options = {
        arn: 'arn:aws:iam::123456789012:role/AliasRole'
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to(
        include('Role Arn: arn:aws:iam::123456789012:role/AliasRole')
      )
    end

    it 'creates with all optional fields' do
      created = Fabricate(:external_aws_account,
                          account_name: 'Full',
                          aws_account_id: '123456789012',
                          role_arn: 'arn:aws:iam::123456789012:role/' \
                                    'FullRole',
                          organization_id: 'o-123',
                          aws_region_primary: 'us-west-2',
                          discovery_enabled: false,
                          discovery_frequency: 'weekly',
                          status: 'active')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        role_arn: 'arn:aws:iam::123456789012:role/FullRole',
        account_name: 'Full',
        aws_account_id: '123456789012',
        organization_id: 'o-123',
        aws_region_primary: 'us-west-2',
        discovery_enabled: false,
        discovery_frequency: 'weekly',
        status: 'active'
      ).and_return(created)

      subject.options = {
        role_arn: 'arn:aws:iam::123456789012:role/FullRole',
        account_name: 'Full',
        aws_account_id: '123456789012',
        organization_id: 'o-123',
        aws_region_primary: 'us-west-2',
        discovery_enabled: false,
        discovery_frequency: 'weekly',
        status: 'active'
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include('Account Name: Full')
      expect(captured_output_text).to include('Aws Account: 123456789012')
    end

    it 'honors --no-discovery-enabled (false case)' do
      created = Fabricate(:external_aws_account,
                          role_arn: 'arn:aws:iam::123456789012:role/NoDisc',
                          discovery_enabled: false)

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        role_arn: 'arn:aws:iam::123456789012:role/NoDisc',
        discovery_enabled: false
      ).and_return(created)

      subject.options = {
        role_arn: 'arn:aws:iam::123456789012:role/NoDisc',
        discovery_enabled: false
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include('Discovery Enabled: false')
    end

    it 'bubbles API errors during create' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).and_raise(
        HyperResource::ClientError.new(
          'Boom',
          response: Faraday::Response.new(status: 500)
        )
      )

      subject.options = { role_arn: 'arn:aws:iam::123456789012:role/Error' }
      expect { subject.send('aws_accounts:add') }.to(
        raise_error(HyperResource::ClientError)
      )
    end

    it 'renders JSON output for create' do
      created = Fabricate(:external_aws_account,
                          role_arn: 'arn:aws:iam::123456789012:role/' \
                                    'JsonRole',
                          account_name: 'JsonName')

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        role_arn: 'arn:aws:iam::123456789012:role/JsonRole',
        account_name: 'JsonName'
      ).and_return(created)

      subject.options = {
        role_arn: 'arn:aws:iam::123456789012:role/JsonRole',
        account_name: 'JsonName'
      }
      subject.send('aws_accounts:add')

      json = captured_output_json
      expect(json['id']).to eq(created.id)
      expect(json['account_name']).to eq('JsonName')
      expect(json['role_arn']).to(
        eq('arn:aws:iam::123456789012:role/JsonRole')
      )
    end
  end

  describe '#aws_accounts:update' do
    it 'updates an external AWS account' do
      ext = double('ext',
                   id: 42,
                   attributes: {
                     'account_name' => 'New Name',
                     'aws_account_id' => '999999999999',
                     'role_arn' => 'arn:aws:iam::999999999999:role/NewRole'
                   })

      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).to receive(:update!).with(
        role_arn: 'arn:aws:iam::999999999999:role/NewRole',
        account_name: 'New Name',
        aws_account_id: '999999999999'
      ).and_return(true)

      subject.options = {
        role_arn: 'arn:aws:iam::999999999999:role/NewRole',
        account_name: 'New Name',
        aws_account_id: '999999999999'
      }
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Id: 42')
      expect(captured_output_text).to include('Account Name: New Name')
      expect(captured_output_text).to include('Aws Account: 999999999999')
      expect(captured_output_text).to(
        include('Role Arn: arn:aws:iam::999999999999:role/NewRole')
      )
    end

    it 'fails when account not found' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([])

      expect { subject.send('aws_accounts:update', '999') }
        .to raise_error(Thor::Error, /External AWS account not found: 999/)
    end

    it 'updates only one field (account_name)' do
      ext = double('ext',
                   id: 42,
                   attributes: {
                     'account_name' => 'Updated Name',
                     'aws_account_id' => '111111111111',
                     'role_arn' => 'arn:aws:iam::111111111111:role/Role'
                   })

      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).to receive(:update!).with(
        account_name: 'Updated Name'
      ).and_return(true)

      subject.options = {
        account_name: 'Updated Name'
      }
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Account Name: Updated Name')
    end

    it 'updates discovery settings separately' do
      ext = double('ext',
                   id: 42,
                   attributes: {
                     'discovery_enabled' => true,
                     'discovery_frequency' => 'hourly'
                   })

      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).to receive(:update!).with(
        discovery_enabled: true,
        discovery_frequency: 'hourly'
      ).and_return(true)

      subject.options = {
        discovery_enabled: true,
        discovery_frequency: 'hourly'
      }
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Discovery Enabled: true')
      expect(captured_output_text).to include('Discovery Frequency: hourly')
    end

    it 'handles empty update gracefully (no changes)' do
      ext = double('ext',
                   id: 42,
                   attributes: {
                     'account_name' => 'Name',
                     'aws_account_id' => '111111111111'
                   })

      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).not_to receive(:update!)

      subject.options = {}
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Id: 42')
    end

    it 'bubbles API errors during update' do
      ext = double('ext', id: 42)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])

      expect(ext).to receive(:update!).and_raise(
        HyperResource::ClientError.new(
          'Boom',
          response: Faraday::Response.new(status: 422)
        )
      )

      subject.options = { account_name: 'X' }
      expect { subject.send('aws_accounts:update', '42') }.to(
        raise_error(HyperResource::ClientError)
      )
    end

    it 'renders JSON output for update' do
      ext = double('ext',
                   id: 7,
                   attributes: {
                     'account_name' => 'JsonUpdated',
                     'aws_account_id' => '123'
                   })

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).to(
        receive(:update!).with(account_name: 'JsonUpdated').and_return(true)
      )

      subject.options = { account_name: 'JsonUpdated' }
      subject.send('aws_accounts:update', '7')

      json = captured_output_json
      expect(json['id']).to eq(7)
      expect(json['account_name']).to eq('JsonUpdated')
    end
  end

  describe '#aws_accounts:delete' do
    it 'deletes an external AWS account' do
      ext = double('ext', id: 24)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).to receive(:destroy!).and_return(true)

      subject.send('aws_accounts:delete', '24')

      expect(captured_output_text).to include('Id: 24')
      expect(captured_output_text).to include('Deleted: true')
    end

    it 'fails when account not found' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([])

      expect { subject.send('aws_accounts:delete', '999') }
        .to raise_error(Thor::Error, /External AWS account not found: 999/)
    end

    it 'supports alternative delete methods' do
      ext = double('ext', id: 24)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])

      expect(ext).to receive(:respond_to?).with(:destroy!).and_return(false)
      expect(ext).to receive(:respond_to?).with(:destroy).and_return(false)
      expect(ext).to receive(:respond_to?).with(:delete!).and_return(true)
      expect(ext).to receive(:delete!).and_return(true)

      subject.send('aws_accounts:delete', '24')

      expect(captured_output_text).to include('Id: 24')
      expect(captured_output_text).to include('Deleted: true')
    end

    it 'raises when delete is not supported' do
      ext = double('ext', id: 24)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])

      expect(ext).to receive(:respond_to?).with(:destroy!).and_return(false)
      expect(ext).to receive(:respond_to?).with(:destroy).and_return(false)
      expect(ext).to receive(:respond_to?).with(:delete!).and_return(false)
      expect(ext).to receive(:respond_to?).with(:delete).and_return(false)

      expect { subject.send('aws_accounts:delete', '24') }
        .to raise_error(Thor::Error, /Delete is not supported/)
    end

    it 'renders JSON output for delete' do
      ext = double('ext', id: 33)
      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')
      expect(Aptible::Api::ExternalAwsAccount).to receive(:all)
        .with(token: token).and_return([ext])
      expect(ext).to receive(:destroy!).and_return(true)

      subject.send('aws_accounts:delete', '33')

      json = captured_output_json
      expect(json['id']).to eq('33')
      expect(json['deleted']).to eq(true)
    end
  end
end
