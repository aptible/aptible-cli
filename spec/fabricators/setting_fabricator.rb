class StubSetting < StubAptibleResource; end

Fabricator(:setting, from: :stub_setting) do
  settings { {} }
  sensitive_settings { {} }

  after_create { |setting| setting.vhost.settings << setting if setting.vhost }
end
