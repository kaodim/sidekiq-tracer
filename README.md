# SidekiqTracer

This gem allows you to add a distributed trace id to your sidekiq jobs in a Rails app.

Say you are serving a web request and queues an async job to worker A. Then later in worker A, it queues another async job to worker B and so forth. As long as you are configuring this gem correctly, you will be able to use an unique uuid to correlate all your web request to all its descendant async jobs.

So basically this gem will do the following:

1. Add an **unique uuid** (which will be configured by you) to a global store within the sidekiq worker context. You can inject this uuid into your logger and later correlate them in your log processing.
2. **Logs all the sql queries** executed within the worker context to the gem logger. (this feature is very opinionated and there's no configuration to opt out at the moment)

## Usage

Make sure you have gem `request-store` installed as this gem is dependent on it while its not included in the gemspec dependency.

```ruby
# config/initializers/sidekiq.rb

SidekiqTracer.configure do |config|
  # The main logger for this gem
  config.logger = SidekiqTraceLogger
  
  # Setup custom info to be logged by the main logger
  config.custom_tracer_options = proc do
    # This is example of injecting additional Datadog trace id
    corr = Datadog&.tracer&.active_correlation

    if corr
      {
        dd: {
          trace_id: corr.trace_id.to_s,
          span_id: corr.span_id.to_s,
          env: corr.env.to_s,
          service: corr.service.to_s,
          version: corr.version.to_s
        },
        ddsource: ['ruby']
      }
    else
      {}
    end
  end

  # This is to prevent so noise in your log correlation as excessive retry might cluttered up your trace
  config.skip_distributed_trace_on = proc do |_worker, job, _queue|
    job['retry_count'].to_i >= 3 # you can set this value dynamically based on the worker name, job info and queue name
  end

  # example forming distributed Datadog trace id
  config.custom_client_distributed_tracer = proc do |_worker, job, _queue|
    dist_trace_id = job['retry_count'].to_i >= 3 ?  nil : job['trace_id']
    corr = Datadog.tracer&.active_correlation
    job.merge!({'trace_id' => dist_trace_id.presence || corr&.trace_id, 'span_id' => corr&.span_id })
end 

# You need to configure the sidekiq client middleware.
# Note that for this part, the gem will try to fetch the uuid from `Current.web_request_id`. 
# As long as you have this class defined with this class method and set the value when the web request starts, it should be fine. 
Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    # push the job to Redis along with the rails request uuid.
    chain.add SidekiqTracer::Sidekiq::Middleware::Client::Tracer
  end
end

# You need to configure the sidekiq server middleware
Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    # push the job to Redis along with the rails request uuid.
    chain.add SidekiqTracer::Sidekiq::Middleware::Client::Tracer
  end

  config.server_middleware do |chain|
    # make the web_request_id available globally via `RequestStore` in the worker environment when sidekiq fetch the job from Redis
    chain.add SidekiqTracer::Sidekiq::Middleware::Server::Tracer if defined? Sidekiq::CLI
  end
end
```

You might spotted a design flaw in which the Sidekiq client middleware relies on `Current` store while the server middleware relies on `RequestStore`. This is due to the assumption that most of you might rely on `ActiveSupport::CurrentAttributes` for global store implementation in your Rails server environment. You should also patch your `Current` class with the following monkey patch to prevent attributes missing in sidekiq server environment.

```ruby
# app/models/current.rb

class Current < ActiveSupport::CurrentAttributes
  attribute :web_request_id
end

if Sidekiq.server?
  module CurrentAttributesExtension
    def web_request_id
      super || RequestStore.read(:web_request_id)
    end
  end
  
  Current.prepend(CurrentAttributesExtension) if Sidekiq.server?
end

```

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'sidekiq_tracer', git: 'https://github.com/kaodim/sidekiq-tracer.git', tag: '<release-version-tag>'
```

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
