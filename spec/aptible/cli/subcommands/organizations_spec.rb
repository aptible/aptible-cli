# frozen_string_literal: true

require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  describe '#organizations' do
    it 'lists organizations' do
      org1 = double('org1', id: 'org-1-id', name: 'Org One', handle: 'org-one')
      org2 = double('org2', id: 'org-2-id', name: 'Org Two', handle: 'org-two')

      expect(Aptible::Auth::Organization).to receive(:all)
        .with(token: token)
        .and_return([org1, org2])

      subject.send('organizations')

      expect(captured_output_text).to include('Id: org-1-id')
      expect(captured_output_text).to include('Name: Org One')
      expect(captured_output_text).to include('Handle: org-one')
      expect(captured_output_text).to include('Id: org-2-id')
      expect(captured_output_text).to include('Name: Org Two')
      expect(captured_output_text).to include('Handle: org-two')
    end

    it 'handles empty list' do
      expect(Aptible::Auth::Organization).to receive(:all)
        .with(token: token)
        .and_return([])

      subject.send('organizations')

      expect(captured_output_text).to eq('')
    end

    it 'handles organizations without handle' do
      org = double('org', id: 'org-id', name: 'Org Name')
      allow(org).to receive(:respond_to?).with(:handle).and_return(false)

      expect(Aptible::Auth::Organization).to receive(:all)
        .with(token: token)
        .and_return([org])

      subject.send('organizations')

      expect(captured_output_text).to include('Id: org-id')
      expect(captured_output_text).to include('Name: Org Name')
      expect(captured_output_text).not_to include('Handle:')
    end

    it 'handles organizations with nil handle' do
      org = double('org', id: 'org-id', name: 'Org Name', handle: nil)

      expect(Aptible::Auth::Organization).to receive(:all)
        .with(token: token)
        .and_return([org])

      subject.send('organizations')

      expect(captured_output_text).to include('Id: org-id')
      expect(captured_output_text).to include('Name: Org Name')
      expect(captured_output_text).not_to include('Handle:')
    end

    it 'renders JSON output' do
      org1 = double('org1', id: 'org-1-id', name: 'Org One', handle: 'org-one')
      org2 = double('org2', id: 'org-2-id', name: 'Org Two', handle: 'org-two')

      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')

      expect(Aptible::Auth::Organization).to receive(:all)
        .with(token: token)
        .and_return([org1, org2])

      subject.send('organizations')

      json = captured_output_json
      expect(json).to be_a(Array)
      expect(json.length).to eq(2)
      expect(json[0]['id']).to eq('org-1-id')
      expect(json[0]['name']).to eq('Org One')
      expect(json[0]['handle']).to eq('org-one')
      expect(json[1]['id']).to eq('org-2-id')
      expect(json[1]['name']).to eq('Org Two')
      expect(json[1]['handle']).to eq('org-two')
    end

    it 'does not include role by default' do
      org = double('org', id: 'org-id', name: 'Org Name', handle: nil)

      expect(Aptible::Auth::Organization).to receive(:all)
        .with(token: token)
        .and_return([org])

      subject.send('organizations')

      expect(captured_output_text).not_to include('Role:')
    end

    context 'with --with-organization-role flag' do
      before { subject.options = { with_organization_role: true } }

      it 'includes user roles in each organization' do
        org1 = double('org1', id: 'org-1-id', name: 'Org One', handle: nil)
        org2 = double('org2', id: 'org-2-id', name: 'Org Two', handle: nil)

        role1_org = double('role1_org', id: 'org-1-id')
        role2_org = double('role2_org', id: 'org-1-id')
        role3_org = double('role3_org', id: 'org-2-id')

        role1 = double('role1', name: 'Admin', organization: role1_org)
        role2 = double('role2', name: 'Developer', organization: role2_org)
        role3 = double('role3', name: 'Account Owners', organization: role3_org)

        user = double('user', roles: [role1, role2, role3])

        expect(Aptible::Auth::Organization).to receive(:all)
          .with(token: token)
          .and_return([org1, org2])

        expect(Aptible::Auth::User).to receive(:all)
          .with(token: token)
          .and_return([user])

        subject.send('organizations')

        expect(captured_output_text).to include('Id: org-1-id')
        expect(captured_output_text).to include('Name: Org One')
        expect(captured_output_text).to include('Role: Admin, Developer')
        expect(captured_output_text).to include('Id: org-2-id')
        expect(captured_output_text).to include('Name: Org Two')
        expect(captured_output_text).to include('Role: Account Owners')
      end

      it 'shows empty role when user has no roles in org' do
        org = double('org', id: 'org-id', name: 'Org Name', handle: nil)
        user = double('user', roles: [])

        expect(Aptible::Auth::Organization).to receive(:all)
          .with(token: token)
          .and_return([org])

        expect(Aptible::Auth::User).to receive(:all)
          .with(token: token)
          .and_return([user])

        subject.send('organizations')

        expect(captured_output_text).to include('Id: org-id')
        expect(captured_output_text).to include('Role:')
      end

      it 'renders JSON output with roles' do
        org = double('org', id: 'org-id', name: 'Org Name', handle: nil)
        role_org = double('role_org', id: 'org-id')
        role = double('role', name: 'Owner', organization: role_org)
        user = double('user', roles: [role])

        allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')

        expect(Aptible::Auth::Organization).to receive(:all)
          .with(token: token)
          .and_return([org])

        expect(Aptible::Auth::User).to receive(:all)
          .with(token: token)
          .and_return([user])

        subject.send('organizations')

        json = captured_output_json
        expect(json).to be_a(Array)
        expect(json[0]['id']).to eq('org-id')
        expect(json[0]['name']).to eq('Org Name')
        expect(json[0]['role']).to eq('Owner')
      end
    end
  end
end
