# raise 'A global threadsafe storage Current is required.' unless defined? Current

require 'sidekiq_tracer/sidekiq/middleware/client/tracer'
require 'sidekiq_tracer/sidekiq/middleware/server/tracer'

module SidekiqTracer
  module_function

  Config = Struct.new(:logger, :custom_tracer_options, :custom_client_distributed_tracer, :skip_distributed_trace_on).new

  def configure
    yield Config
  end

  def configuration
    Config
  end

  def logger
    Config.logger
  end

  def skip_distributed_trace_on
    Config.skip_distributed_trace_on
  end
end
