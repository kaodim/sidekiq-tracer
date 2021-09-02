require 'lograge/sql/extension'
require 'lograge/cache/extension'

module SidekiqTracer
  module Sidekiq
    module Middleware
      module Server
        class Tracer
          include Lograge::Sql::Extension
          include Lograge::Cache::Extension

          def call(worker, item, queue)
            globalized_request_id(worker, item, queue)
            start = Time.current
            yield
            duration = (Time.current - start) * 1_000
            payload = {
              "message" => item.slice('args').to_json,
              "duration" => duration,
              "request_id" => item['request_id'],
              "worker" => worker.class.to_s,
              "queue" => queue,
              "jid" => item['jid'],
              "bid" => item['bid'],
              "sql_queries" => extract_queries
            }.merge(custom_tracer_options)
            logger.info(payload)
          rescue StandardError => e
            payload = {
              "message" => item.slice('args').merge('error' => e.message, 'backtrace' => e.backtrace[0..40].join("\n")).to_json,
              "duration" => (Time.current - start) * 1_000,
              "request_id" => item['request_id'],
              "worker" => worker.class.to_s,
              "queue" => queue,
              "jid" => item['jid'],
              "bid" => item['bid'],
              "sql_queries" => extract_queries
            }.merge(custom_tracer_options)
            logger.error(payload)
            raise e
          ensure
            Current.reset
          end

          def globalized_request_id(_worker, item, _queue)
            Current.web_request_id = item['request_id'] if item['request_id']
          end

          def extract_queries
            queries_stats = { queries: [], queries_count: 0 }
            cached_queries_stats = extract_cache_queries
            sql_queries_stats = extract_sql_queries

            queries_count = cached_queries_stats[:cache_count].to_i + sql_queries_stats[:sql_queries_count].to_i
            queries_stats[:count] = queries_count

            queries = Array(cached_queries_stats[:cache_queries]) + Array(sql_queries_stats[:sql_queries])
            queries_stats[:queries] = queries.compact.sort_by {|q| q[:timestamp] }

            queries
          end

          def logger
            SidekiqTracer.logger
          end

          def custom_tracer_options
            (SidekiqTracer.configuration.custom_tracer_options&.call || {}).deep_stringify_keys
          end
        end
      end
    end
  end
end
