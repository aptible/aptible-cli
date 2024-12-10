module Aptible
  module CLI
    module Subcommands
      module Services
        def self.included(thor)
          thor.class_eval do
            include Helpers::App

            desc 'services', 'List Services for an App'
            app_options
            def services
              app = ensure_app(options)

              Formatter.render(Renderer.current) do |root|
                root.list do |list|
                  app.each_service do |service|
                    list.object do |node|
                      ResourceFormatter.inject_service(node, service, app)
                    end
                  end
                end
              end
            end

            desc 'services:settings SERVICE'\
                   ' [--force-zero-downtime|--no-force-zero-downtime]'\
                   ' [--simple-health-check|--no-simple-health-check]',
                 'Modifies the zero-downtime deploy setting for a service'
            app_options
            option :force_zero_downtime,
                   type: :boolean, default: false,
                   desc: 'Force zero downtime deployments.'\
                   ' Has no effect if service has an associated Endpoint'
            option :simple_health_check,
                   type: :boolean, default: false,
                   desc: 'Use a simple uptime healthcheck during deployments'
            define_method 'services:settings' do |service|
              service = ensure_service(options, service)
              updates = {}
              updates[:force_zero_downtime] =
                options[:force_zero_downtime] if options[:force_zero_downtime]
              updates[:naive_health_check] =
                options[:simple_health_check] if options[:simple_health_check]

              service.update!(**updates) if updates.any?
            end

            desc 'services:sizing_policy SERVICE',
                 'Returns the associated sizing policy, if any'
            app_options
            define_method 'services:sizing_policy' do |service|
              service = ensure_service(options, service)
              policy = service.service_sizing_policy

              unless policy
                raise Thor::Error, "Service #{service} does not have a " \
                  'service sizing policy set'
              end

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  ResourceFormatter.inject_service_sizing_policy(
                    node, policy, service
                  )
                end
              end
            end
            alias_method 'services:autoscaling_policy',
                         'services:sizing_policy'

            desc 'services:sizing_policy:set SERVICE '\
                   '--autoscaling-type (horizontal|vertical) '\
                   '[--metric-lookback-seconds SECONDS] '\
                   '[--percentile PERCENTILE] '\
                   '[--post-scale-up-cooldown-seconds SECONDS] '\
                   '[--post-scale-down-cooldown-seconds SECONDS] '\
                   '[--post-release-cooldown-seconds SECONDS] '\
                   '[--mem-cpu-ratio-r-threshold RATIO] '\
                   '[--mem-cpu-ratio-c-threshold RATIO] '\
                   '[--mem-scale-up-threshold THRESHOLD] '\
                   '[--mem-scale-down-threshold THRESHOLD] '\
                   '[--minimum-memory MEMORY] '\
                   '[--maximum-memory MEMORY] '\
                   '[--min-cpu-threshold THRESHOLD] '\
                   '[--max-cpu-threshold THRESHOLD] '\
                   '[--min-containers CONTAINERS] '\
                   '[--max-containers CONTAINERS] '\
                   '[--scale-up-step STEPS] '\
                   '[--scale-down-step STEPS] ',
                 'Sets the sizing (autoscaling) policy for a service.'\
                   ' This is not incremental, all arguments must be sent'\
                   ' at once or they will be set to defaults.'
            app_options
            option :autoscaling_type,
                   type: :string,
                   desc: 'The type of autoscaling. Must be either '\
                   '"horizontal" or "vertical"'
            option :metric_lookback_seconds,
                   type: :numeric,
                   desc: '(Default: 1800) The duration in seconds for '\
                   'retrieving past performance metrics.'
            option :percentile,
                   type: :numeric,
                   desc: '(Default: 99) The percentile for evaluating metrics.'
            option :post_scale_up_cooldown_seconds,
                   type: :numeric,
                   desc: '(Default: 60) The waiting period in seconds after '\
                   'an automated scale-up before another scaling action can '\
                   'be considered.'
            option :post_scale_down_cooldown_seconds,
                   type: :numeric,
                   desc: '(Default: 300) The waiting period in seconds after '\
                   'an automated scale-down before another scaling action can '\
                   'be considered.'
            option :post_release_cooldown_seconds,
                   type: :numeric,
                   desc: '(Default: 300) The time in seconds to wait '\
                   'following a deploy before another scaling action can '\
                   'be considered.'
            option :mem_cpu_ratio_r_threshold,
                   type: :numeric,
                   desc: '(Default: 4.0) Establishes the ratio of Memory '\
                   '(in GB) to CPU (in CPUs) at which values exceeding the '\
                   'threshold prompt a shift to an R (Memory Optimized) '\
                   'profile.'
            option :mem_cpu_ratio_c_threshold,
                   type: :numeric,
                   desc: '(Default: 2.0) Sets the Memory-to-CPU ratio '\
                   'threshold, below which the service is transitioned to a '\
                   'C (Compute Optimized) profile.'
            option :mem_scale_up_threshold,
                   type: :numeric,
                   desc: '(Default: 0.9) Vertical autoscaling only - '\
                   'Specifies the percentage of the current memory limit '\
                   'at which the service’s memory usage triggers an '\
                   'up-scaling action.'
            option :mem_scale_down_threshold,
                   type: :numeric,
                   desc: '(Default: 0.75) Vertical autoscaling only - '\
                   'Specifies the percentage of the current memory limit at '\
                   'which the service’s memory usage triggers a '\
                   'down-scaling action.'
            option :minimum_memory,
                   type: :numeric,
                   desc: '(Default: 2048) Vertical autoscaling only - Sets '\
                   'the lowest memory limit to which the service can be '\
                   'scaled down by Autoscaler.'
            option :maximum_memory,
                   type: :numeric,
                   desc: 'Vertical autoscaling only - Defines the upper '\
                   'memory threshold, capping the maximum memory allocation'\
                   ' possible through Autoscaler. If blank, the container can'\
                   ' scale to the largest size available.'
            option :min_cpu_threshold,
                   type: :numeric,
                   desc: 'Horizontal autoscaling only - Specifies the '\
                   'percentage of the current CPU usage at which a '\
                   'down-scaling action is triggered.'
            option :max_cpu_threshold,
                   type: :numeric,
                   desc: 'Horizontal autoscaling only - Specifies the '\
                   'percentage of the current CPU usage at which an '\
                   'up-scaling action is triggered.'
            option :min_containers,
                   type: :numeric,
                   desc: 'Horizontal autoscaling only - Sets the lowest'\
                   ' container count to which the service can be scaled down.'
            option :max_containers,
                   type: :numeric,
                   desc: 'Horizontal autoscaling only - Sets the highest '\
                   'container count to which the service can be scaled up to.'
            option :scale_up_step,
                   type: :numeric,
                   desc: '(Default: 1) Horizontal autoscaling only - Sets '\
                   'the amount of containers to add when autoscaling (ex: a '\
                   'value of 2 will go from 1->3->5). Container count will '\
                   'never exceed the configured maximum.'
            option :scale_down_step,
                   type: :numeric,
                   desc: '(Default: 1) Horizontal autoscaling only - Sets '\
                   'the amount of containers to remove when autoscaling (ex:'\
                   ' a value of 2 will go from 4->2->1). Container count '\
                   'will never exceed the configured minimum.'
            define_method 'services:sizing_policy:set' do |service|
              service = ensure_service(options, service)
              ignored_attrs = %i(autoscaling_type app environment remote)
              args = options.except(*ignored_attrs)
              args[:autoscaling] = options[:autoscaling_type]

              sizing_policy = service.service_sizing_policy
              if sizing_policy
                sizing_policy.update!(**args)
              else
                service.create_service_sizing_policy!(**args)
              end
            end
            alias_method 'services:autoscaling_policy:set',
                         'services:sizing_policy:set'
          end
        end
      end
    end
  end
end
