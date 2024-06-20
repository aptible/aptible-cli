class StubBackupRetentionPolicy < OpenStruct
  def reload
    self
  end
end

Fabricator(:backup_retention_policy, from: :stub_backup_retention_policy) do
  id { sequence(:backup_retention_policy_id) }
  created_at { Time.now }
  daily { 30 }
  monthly { 12 }
  yearly { 6 }
  make_copy { true }
  keep_final { true }
  account

  after_create { |policy| policy.account.backup_retention_policies << policy }
end
