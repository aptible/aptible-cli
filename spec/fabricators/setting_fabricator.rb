class StubConfiguration < OpenStruct
end

Fabricator(:setting, from: :stub_configuration) do
  settings { {} }
  sensitive_settings { {} }

  after_create { |setting| vhost.settings << setting }
end
