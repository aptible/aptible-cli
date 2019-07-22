class StubConfiguration < OpenStruct
end

Fabricator(:configuration, from: :stub_configuration) do
  env { {} }

  after_create { |configuration| app.configurations << configuration }
end
