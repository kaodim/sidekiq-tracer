module SidekiqTracer
  module Sidekiq
    module Middleware
      module Client
        class Tracer
          def call(worker_class, msg, queue, _redis_pool)
            msg['request_id'] ||= Current.web_request_id if defined?(Current) && Current.web_request_id.present?
            custom_client_distributed_tracer(worker_class, msg, queue)
            yield
          end

          private

          def custom_client_distributed_tracer(worker_class, msg, queue)
            SidekiqTracer.configuration.custom_client_distributed_tracer&.call(worker_class, msg, queue)
          end
        end
      end
    end
  end
end
