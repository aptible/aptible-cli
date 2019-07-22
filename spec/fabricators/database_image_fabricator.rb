class StubDatabaseImage < OpenStruct
end

Fabricator(:database_image, from: :stub_database_image) do
  type { 'postgresql' }
  version { '9.4' }

  after_create do |image|
    if image.description.nil?
      image.description = "#{image.type} #{image.version}"
    end

    if image.docker_repo.nil?
      image.docker_repo = "aptible/#{image.type}:#{image.version}"
    end
  end
end
