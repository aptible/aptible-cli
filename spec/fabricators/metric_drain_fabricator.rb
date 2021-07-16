class StubMetricDrain < OpenStruct; end

Fabricator(:metric_drain, from: :stub_metric_drain) do
  id { sequence(:metric_drain_id) }
  account

  after_create { |drain| drain.account.metric_drains << drain }
end
