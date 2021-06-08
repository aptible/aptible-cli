class StubDatabaseDisk < OpenStruct
end

Fabricator(:database_disk, from: :stub_database_disk) do
  size 100
  ebs_volume_type { 'gp2' }
  baseline_iops '300'
end
