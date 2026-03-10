class StubMetricDrain < StubAptibleResource
  def attributes
    # Don't blame me, I'm just following the example in StubLogDrain,
    # see the comment there.
    {
      'drain_configuration' => drain_configuration
    }
  end
end

Fabricator(:metric_drain, from: :stub_metric_drain) do
  id { sequence(:metric_drain_id) }
  drain_configuration do
    {
      'api_key' => 'asdf',
      'series_url' => 'https://localhost.aptible.in/api/v1/series'
    }
  end
  account
  links do |attrs|
    hash = {
      account: OpenStruct.new(
        href: "/accounts/#{attrs[:account].id}"
      )
    }
    OpenStruct.new(hash)
  end

  after_create { |drain| drain.account.metric_drains << drain }
end
