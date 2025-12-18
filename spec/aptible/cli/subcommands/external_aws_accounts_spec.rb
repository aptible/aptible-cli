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
                     discovery_role_arn: 'arn:aws:iam::111111111111:role/' \
                               'DevRole')
      a2 = Fabricate(:external_aws_account,
                     account_name: 'Prod',
                     aws_account_id: '222222222222',
                     discovery_role_arn: 'arn:aws:iam::222222222222:role/' \
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
        include('Discovery Role Arn: arn:aws:iam::111111111111:role/DevRole')
      )

      expect(captured_output_text).to include("Id: #{a2.id}")
      expect(captured_output_text).to include('Account Name: Prod')
      expect(captured_output_text).to include('Aws Account: 222222222222')
      expect(captured_output_text).to(
        include('Discovery Role Arn: arn:aws:iam::222222222222:role/ProdRole')
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
      a1 = Fabricate(
        :external_aws_account,
        account_name: 'Dev',
        aws_account_id: '111111111111',
        discovery_role_arn: 'arn:aws:iam::111111111111:role/DevRole'
      )

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
      expect(json.first['discovery_role_arn']).to(
        eq('arn:aws:iam::111111111111:role/DevRole')
      )
    end
  end

  describe '#aws_accounts:add' do
    it 'creates an external AWS account' do
      org = double('org', id: 'org-123')
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([org])

      created = Fabricate(
        :external_aws_account,
        account_name: 'Staging',
        aws_account_id: '123456789012',
        discovery_role_arn: 'arn:aws:iam::123456789012:role/' \
                  'StagingRole',
        discovery_enabled: true,
        discovery_frequency: 'daily',
        aws_region_primary: 'us-east-1'
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/StagingRole',
        account_name: 'Staging',
        aws_account_id: '123456789012',
        organization_id: 'org-123',
        aws_region_primary: 'us-east-1',
        discovery_enabled: true,
        discovery_frequency: 'daily'
      ).and_return(created)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/StagingRole',
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
      expect(captured_output_text).to include(
        'Discovery Role Arn: arn:aws:iam::123456789012:role/StagingRole'
      )
    end

    it 'creates with minimal options (discovery_role_arn only)' do
      org = double('org', id: 'org-123')
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([org])

      created = Fabricate(
        :external_aws_account,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/MinRole'
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/MinRole',
        organization_id: 'org-123'
      ).and_return(created)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/MinRole'
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include("Id: #{created.id}")
      expect(captured_output_text).to include(
        'Discovery Role Arn: arn:aws:iam::123456789012:role/MinRole'
      )
    end

    it 'creates with organization_id provided' do
      created = Fabricate(
        :external_aws_account,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/AliasRole'
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/AliasRole',
        organization_id: 'explicit-org-id'
      ).and_return(created)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/AliasRole',
        organization_id: 'explicit-org-id'
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include(
        'Discovery Role Arn: arn:aws:iam::123456789012:role/AliasRole'
      )
    end

    it 'creates with all optional fields' do
      created = Fabricate(
        :external_aws_account,
        account_name: 'Full',
        aws_account_id: '123456789012',
        discovery_role_arn: 'arn:aws:iam::123456789012:role/FullRole',
        organization_id: 'o-123',
        aws_region_primary: 'us-west-2',
        discovery_enabled: false,
        discovery_frequency: 'weekly',
        status: 'active'
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/FullRole',
        account_name: 'Full',
        aws_account_id: '123456789012',
        organization_id: 'o-123',
        aws_region_primary: 'us-west-2',
        discovery_enabled: false,
        discovery_frequency: 'weekly',
        status: 'active'
      ).and_return(created)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/FullRole',
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
      org = double('org', id: 'org-123')
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([org])

      created = Fabricate(
        :external_aws_account,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/NoDisc',
        discovery_enabled: false
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/NoDisc',
        organization_id: 'org-123',
        discovery_enabled: false
      ).and_return(created)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/NoDisc',
        discovery_enabled: false
      }
      subject.send('aws_accounts:add')

      expect(captured_output_text).to include('Discovery Enabled: false')
    end

    it 'bubbles API errors during create' do
      org = double('org', id: 'org-123')
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([org])

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).and_raise(
        HyperResource::ClientError.new(
          'Boom',
          response: Faraday::Response.new(status: 500)
        )
      )

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/Error'
      }
      expect { subject.send('aws_accounts:add') }.to(
        raise_error(Thor::Error, /Boom/)
      )
    end

    it 'renders JSON output for create' do
      org = double('org', id: 'org-123')
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([org])

      created = Fabricate(
        :external_aws_account,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/JsonRole',
        account_name: 'JsonName'
      )

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')

      expect(Aptible::Api::ExternalAwsAccount).to receive(:create).with(
        token: token,
        discovery_role_arn: 'arn:aws:iam::123456789012:role/JsonRole',
        account_name: 'JsonName',
        organization_id: 'org-123'
      ).and_return(created)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/JsonRole',
        account_name: 'JsonName'
      }
      subject.send('aws_accounts:add')

      json = captured_output_json
      expect(json['id']).to eq(created.id)
      expect(json['account_name']).to eq('JsonName')
      expect(json['discovery_role_arn']).to(
        eq('arn:aws:iam::123456789012:role/JsonRole')
      )
    end

    it 'fails when no organizations found and no org_id provided' do
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([])

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/TestRole'
      }

      expect { subject.send('aws_accounts:add') }.to(
        raise_error(Thor::Error, /No organizations found/)
      )
    end

    it 'fails when multiple organizations found and no org_id provided' do
      org1 = double('org1', id: 'org-1', name: 'org one')
      org2 = double('org2', id: 'org-2', name: 'org two')
      allow(Aptible::Auth::Organization).to receive(:all)
        .with(token: token).and_return([org1, org2])

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::123456789012:role/TestRole'
      }

      expect { subject.send('aws_accounts:add') }.to(
        raise_error(Thor::Error, /Multiple organizations found/)
      )
    end
  end

  describe '#aws_accounts:update' do
    it 'updates an external AWS account' do
      errors = Aptible::Resource::Errors.new
      ext = double(
        'ext',
        id: 42,
        errors: errors,
        attributes: {
          'account_name' => 'New Name',
          'aws_account_id' => '999999999999',
          'discovery_role_arn' =>
            'arn:aws:iam::999999999999:role/NewRole'
        }
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      expect(ext).to receive(:update!).with(
        discovery_role_arn: 'arn:aws:iam::999999999999:role/NewRole',
        account_name: 'New Name',
        aws_account_id: '999999999999'
      ).and_return(true)

      subject.options = {
        discovery_role_arn: 'arn:aws:iam::999999999999:role/NewRole',
        account_name: 'New Name',
        aws_account_id: '999999999999'
      }
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Id: 42')
      expect(captured_output_text).to include('Account Name: New Name')
      expect(captured_output_text).to include('Aws Account: 999999999999')
      expect(captured_output_text).to(
        include('Discovery Role Arn: arn:aws:iam::999999999999:role/NewRole')
      )
    end

    it 'fails when account not found' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('999', token: token).and_return(nil)

      expect { subject.send('aws_accounts:update', '999') }
        .to raise_error(Thor::Error, /External AWS account not found: 999/)
    end

    it 'updates only one field (account_name)' do
      errors = Aptible::Resource::Errors.new
      ext = double(
        'ext',
        id: 42,
        errors: errors,
        attributes: {
          'account_name' => 'Updated Name',
          'aws_account_id' => '111111111111',
          'discovery_role_arn' => 'arn:aws:iam::111111111111:role/Role'
        }
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
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
      errors = Aptible::Resource::Errors.new
      ext = double('ext',
                   id: 42,
                   errors: errors,
                   attributes: {
                     'discovery_enabled' => true,
                     'discovery_frequency' => 'hourly'
                   })

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
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

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      expect(ext).not_to receive(:update!)

      subject.options = {}
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Id: 42')
    end

    it 'bubbles API errors during update' do
      ext = double('ext', id: 42)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)

      expect(ext).to receive(:update!).and_raise(
        HyperResource::ClientError.new(
          'Boom',
          response: Faraday::Response.new(status: 422)
        )
      )

      subject.options = { account_name: 'X' }
      expect { subject.send('aws_accounts:update', '42') }.to(
        raise_error(Thor::Error, /Boom/)
      )
    end

    it 'renders JSON output for update' do
      errors = Aptible::Resource::Errors.new
      ext = double('ext',
                   id: 7,
                   errors: errors,
                   attributes: {
                     'account_name' => 'JsonUpdated',
                     'aws_account_id' => '123'
                   })

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('7', token: token).and_return(ext)
      expect(ext).to(
        receive(:update!).with(account_name: 'JsonUpdated').and_return(true)
      )

      subject.options = { account_name: 'JsonUpdated' }
      subject.send('aws_accounts:update', '7')

      json = captured_output_json
      expect(json['id']).to eq(7)
      expect(json['account_name']).to eq('JsonUpdated')
    end

    it 'removes discovery_role_arn with --remove-discovery-role-arn' do
      errors = Aptible::Resource::Errors.new
      ext = double(
        'ext',
        id: 42,
        errors: errors,
        attributes: {
          'account_name' => 'Test',
          'aws_account_id' => '111111111111'
        }
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      expect(ext).to receive(:update!).with(
        discovery_role_arn: ''
      ).and_return(true)

      subject.options = { remove_discovery_role_arn: true }
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Id: 42')
    end

    it 'ignores --discovery-role-arn when --remove-discovery-role-arn is set' do
      errors = Aptible::Resource::Errors.new
      ext = double(
        'ext',
        id: 42,
        errors: errors,
        attributes: {
          'account_name' => 'Test',
          'aws_account_id' => '111111111111'
        }
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      # Should send empty string, not the provided ARN
      expect(ext).to receive(:update!).with(
        discovery_role_arn: ''
      ).and_return(true)

      subject.options = {
        remove_discovery_role_arn: true,
        discovery_role_arn: 'arn:aws:iam::111111111111:role/ShouldBeIgnored'
      }
      subject.send('aws_accounts:update', '42')

      expect(captured_output_text).to include('Id: 42')
    end
  end

  describe '#aws_accounts:show' do
    it 'shows an external AWS account' do
      ext = Fabricate(
        :external_aws_account,
        id: 42,
        account_name: 'ShowTest',
        aws_account_id: '123456789012',
        discovery_role_arn: 'arn:aws:iam::123456789012:role/TestRole',
        discovery_enabled: true,
        discovery_frequency: 'daily'
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)

      subject.send('aws_accounts:show', '42')

      expect(captured_output_text).to include('Id: 42')
      expect(captured_output_text).to include('Account Name: ShowTest')
      expect(captured_output_text).to include('Aws Account: 123456789012')
      expect(captured_output_text).to(
        include('Discovery Role Arn: arn:aws:iam::123456789012:role/TestRole')
      )
      expect(captured_output_text).to include('Discovery Enabled: true')
      expect(captured_output_text).to include('Discovery Frequency: daily')
    end

    it 'fails when account not found' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('999', token: token).and_return(nil)

      expect { subject.send('aws_accounts:show', '999') }
        .to raise_error(Thor::Error, /External AWS account not found: 999/)
    end

    it 'renders JSON output' do
      ext = Fabricate(
        :external_aws_account,
        id: 7,
        account_name: 'JsonShow',
        aws_account_id: '987654321098',
        discovery_role_arn: 'arn:aws:iam::987654321098:role/JsonRole'
      )

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('7', token: token).and_return(ext)

      subject.send('aws_accounts:show', '7')

      json = captured_output_json
      expect(json['id']).to eq(7)
      expect(json['account_name']).to eq('JsonShow')
      expect(json['aws_account_id']).to eq('987654321098')
      expect(json['discovery_role_arn']).to(
        eq('arn:aws:iam::987654321098:role/JsonRole')
      )
    end
  end

  describe '#aws_accounts:delete' do
    it 'deletes an external AWS account' do
      ext = double('ext', id: 24)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('24', token: token).and_return(ext)
      expect(ext).to receive(:destroy!).and_return(true)

      subject.send('aws_accounts:delete', '24')

      expect(captured_output_text).to include('Id: 24')
      expect(captured_output_text).to include('Deleted: true')
    end

    it 'fails when account not found' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('999', token: token).and_return(nil)

      expect { subject.send('aws_accounts:delete', '999') }
        .to raise_error(Thor::Error, /External AWS account not found: 999/)
    end

    it 'supports alternative delete methods' do
      ext = double('ext', id: 24)
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('24', token: token).and_return(ext)

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
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('24', token: token).and_return(ext)

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
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('33', token: token).and_return(ext)
      expect(ext).to receive(:destroy!).and_return(true)

      subject.send('aws_accounts:delete', '33')

      json = captured_output_json
      expect(json['id']).to eq('33')
      expect(json['deleted']).to eq(true)
    end
  end

  describe '#aws_accounts:check' do
    it 'raises error when account not found' do
      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(nil)

      expect { subject.send('aws_accounts:check', '42') }.to(
        raise_error(Thor::Error, /External AWS account not found: 42/)
      )
    end

    it 'checks an external AWS account successfully' do
      ext = double('ext', id: 42)
      check_result = double(
        'check_result',
        state: 'success',
        checks: [
          double('check', check_name: 'role_access', state: 'success',
                          details: nil)
        ]
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      expect(ext).to receive(:check!).and_return(check_result)

      # check command uses puts directly (not Formatter) for non-JSON output
      expect { subject.send('aws_accounts:check', '42') }.to output(
        /State:.*success/m
      ).to_stdout
    end

    it 'raises error on check failure' do
      ext = double('ext', id: 42)
      check_result = double(
        'check_result',
        state: 'failed',
        checks: [
          double('check', check_name: 'role_access', state: 'failed',
                          details: 'Access denied')
        ]
      )

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      expect(ext).to receive(:check!).and_return(check_result)

      expect { subject.send('aws_accounts:check', '42') }.to(
        raise_error(Thor::Error, /AWS account check failed/)
      )
    end

    it 'handles API errors during check' do
      ext = double('ext', id: 42)

      expect(Aptible::Api::ExternalAwsAccount).to receive(:find)
        .with('42', token: token).and_return(ext)
      expect(ext).to receive(:check!).and_raise(
        HyperResource::ClientError.new(
          'Check failed',
          response: Faraday::Response.new(status: 500)
        )
      )

      expect { subject.send('aws_accounts:check', '42') }.to(
        raise_error(Thor::Error, /Check failed/)
      )
    end
  end
end
