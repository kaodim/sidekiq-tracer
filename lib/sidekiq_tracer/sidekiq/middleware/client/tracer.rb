module SidekiqTracer
  module Sidekiq
    module Middleware
      module Client
        class Tracer
          def call(worker_class, msg, queue, _redis_pool)
            msg['request_id'] ||= Current.web_request_id if defined?(Current) && Current.web_request_id.present?
            dist_trace_id = SidekiqTracer.skip_distributed_trace_on&.call(worker_class, msg, queue) ? nil : msg['trace_id']
            msg.merge!(dd_trace(trace_id: dist_trace_id))
            yield
          end

          private

          # @param [String] trace_id This will propagate the input trace id to form distributed nested tracing
          def dd_trace(trace_id: nil)
            corr = Datadog.tracer&.active_correlation
            { 'trace_id' => trace_id.presence || corr&.trace_id, 'span_id' => corr&.span_id }
          end
        end
      end
    end
  end
end
