class StubMetricDrain < OpenStruct; end

Fabricator(:metric_drain, from: :stub_metric_drain) do
  id { sequence(:metric_drain_id) }
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
