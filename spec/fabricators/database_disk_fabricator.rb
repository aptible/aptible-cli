class StubDatabaseDisk < OpenStruct
end

Fabricator(:database_disk, from: :stub_database_disk) do
  size 100
  ebs_volume_type { 'gb2' }
end
