class StubServiceSizingPolicy < OpenStruct; end

Fabricator(:service_sizing_policy, from: :stub_service_sizing_policy) do
  autoscaling 'vertical'
  metric_lookback_seconds 1800
  percentile 99.0
  post_scale_up_cooldown_seconds 60
  post_scale_down_cooldown_seconds 300
  post_release_cooldown_seconds 300
  mem_cpu_ratio_r_threshold 4
  mem_cpu_ratio_c_threshold 2
  mem_scale_up_threshold 0.9
  mem_scale_down_threshold 0.75
  minimum_memory 2048
  maximum_memory nil
  min_cpu_threshold 0.4
  max_cpu_threshold 0.9
  min_containers 2
  max_containers 5
  scale_up_step 1
  scale_down_step 1
end
