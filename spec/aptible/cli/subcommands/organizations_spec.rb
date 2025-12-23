# frozen_string_literal: true

require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  describe '#organizations' do
    let(:org1) { double('org1', id: 'org-1-id', name: 'Org One') }
    let(:org2) { double('org2', id: 'org-2-id', name: 'Org Two') }
    let(:role1) { double('role1', id: 'role-1-id', name: 'Admin', organization: org1) }
    let(:role2) { double('role2', id: 'role-2-id', name: 'Developer', organization: org1) }
    let(:role3) { double('role3', id: 'role-3-id', name: 'Account Owners', organization: org2) }
    let(:user) { double('user', roles_with_organizations: [role1, role2, role3]) }
    let(:current_token) { double('current_token', user: user) }

    before do
      allow(Aptible::Auth::Token).to receive(:current_token)
        .with(token: token)
        .and_return(current_token)
    end

    it 'lists organizations with roles' do
      subject.send('organizations')

      expect(captured_output_text).to include('Id: org-1-id')
      expect(captured_output_text).to include('Name: Org One')
      expect(captured_output_text).to include('Id: org-2-id')
      expect(captured_output_text).to include('Name: Org Two')
      expect(captured_output_text).to include('Roles:')
      expect(captured_output_text).to include('Name: Admin')
      expect(captured_output_text).to include('Name: Developer')
      expect(captured_output_text).to include('Name: Account Owners')
    end

    it 'handles user with no roles' do
      allow(user).to receive(:roles_with_organizations).and_return([])

      subject.send('organizations')

      expect(captured_output_text).to eq('')
    end

    it 'renders JSON output' do
      allow(Aptible::CLI::Renderer).to receive(:format).and_return('json')

      subject.send('organizations')

      json = captured_output_json
      expect(json).to be_a(Array)
      expect(json.length).to eq(2)

      org1_json = json.find { |o| o['id'] == 'org-1-id' }
      expect(org1_json['name']).to eq('Org One')
      expect(org1_json['roles'].length).to eq(2)
      expect(org1_json['roles'].map { |r| r['name'] }).to contain_exactly('Admin', 'Developer')

      org2_json = json.find { |o| o['id'] == 'org-2-id' }
      expect(org2_json['name']).to eq('Org Two')
      expect(org2_json['roles'].length).to eq(1)
      expect(org2_json['roles'][0]['name']).to eq('Account Owners')
    end
  end
end
