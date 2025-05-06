# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module Langfuse
  class BatchWorker
    extend T::Sig
    # This is a placeholder class that will be defined with Sidekiq::Worker
    # when Sidekiq is available.
    #
    # If Sidekiq is available, this will be replaced with a real worker class
    # that includes Sidekiq::Worker

    # Ensure return type matches the synchronous perform call
    sig { params(events: T::Array[T::Hash[T.untyped, T.untyped]]).void }
    def self.perform_async(events)
      # When Sidekiq is not available, process synchronously and return result
      new.perform(events)
    end

    sig { params(events: T::Array[T::Hash[T.untyped, T.untyped]]).returns(T::Hash[String, T.untyped]) }
    def perform(events)
      # Assuming Langfuse.configuration returns a valid config object for ApiClient
      T.unsafe(Langfuse::ApiClient).new(T.unsafe(Langfuse).configuration).ingest(events)
    end
  end

  # Define the real Sidekiq worker if Sidekiq is available
  if defined?(Sidekiq)
    class BatchWorker
      # Re-extend T::Sig within the conditional definition
      extend T::Sig
      # Include Sidekiq::Worker directly - rely on T.unsafe for its methods
      include Sidekiq::Worker

      # Using T.unsafe for sidekiq_options DSL
      T.unsafe(self).sidekiq_options queue: 'langfuse', retry: 5, backtrace: true

      # Custom retry delay logic (exponential backoff)
      # Using T.unsafe for sidekiq_retry_in DSL
      T.unsafe(self).sidekiq_retry_in do |count|
        10 * (count + 1) # 10s, 20s, 30s, 40s, 50s
      end

      sig { params(event_hashes: T::Array[T::Hash[T.untyped, T.untyped]]).void }
      def perform(event_hashes)
        # Assuming Langfuse.configuration returns a valid config object
        api_client = T.unsafe(ApiClient).new(T.unsafe(Langfuse).configuration)

        begin
          response = api_client.ingest(event_hashes)

          # Check for partial failures using standard hash access
          errors = T.let(response['errors'], T.nilable(T::Array[T::Hash[String, T.untyped]]))
          if errors && errors.any?
            errors.each do |error|
              T.unsafe(self).logger.error("Langfuse API error for event #{error['id']}: #{error['message']}")

              # Store permanently failed events if needed
              next if retryable_error?(error)

              # Find the failed event
              failed_event = event_hashes.find { |e| T.unsafe(e)[:id] == error['id'] }
              store_failed_event(failed_event, T.cast(error['message'], String)) if failed_event
            end
          end
        rescue Langfuse::RateLimitError => e
          # Special handling for rate limits
          retry_after = e.retry_after || 30 # Default to 30 seconds if not specified
          T.unsafe(self).logger.warn("Langfuse rate limit exceeded. Retrying in #{retry_after} seconds.")

          # Requeue the job with a delay based on retry_after
          # This is Sidekiq-specific and would need adjustment for other job processors
          T.unsafe(self.class).perform_in(retry_after, event_hashes)
        rescue Langfuse::RetryableError => e
          # Get the suggested retry delay if available
          retry_delay = e.suggested_retry_delay

          if retry_delay
            T.unsafe(self).logger.warn("Langfuse retryable error: #{e.message}. Retrying in #{retry_delay} seconds.")
            T.unsafe(self.class).perform_in(retry_delay, event_hashes)
          else
            # Let Sidekiq handle the retry for other retryable errors
            T.unsafe(self).logger.error("Langfuse retryable error: #{e.message}")
            raise
          end
        rescue Langfuse::ValidationError => e
          # Log validation details if available
          if e.validation_details
            T.unsafe(self).logger.error("Langfuse validation error: #{e.message}, details: #{e.validation_details}")
          else
            T.unsafe(self).logger.error("Langfuse validation error: #{e.message}")
          end

          # Store all events as failed
          event_hashes.each do |event|
            store_failed_event(event, e.message)
          end
        rescue Langfuse::APIError => e
          # Non-retryable API errors
          T.unsafe(self).logger.error("Langfuse API error: #{e.message}")

          # Store all events as failed
          event_hashes.each do |event|
            store_failed_event(event, e.message)
          end
        rescue StandardError => e
          # Other unexpected errors
          T.unsafe(self).logger.error("Langfuse unexpected error: #{e.message}")
          raise
        end
      end

      private

      sig { params(error: T::Hash[String, T.untyped]).returns(T::Boolean) }
      def retryable_error?(error)
        # Check if this is a retryable error based on status code
        status = T.let(error['status'], T.untyped)
        status_int = T.let(status.to_i, Integer)

        # 429 (rate limit) and 5xx (server errors) are retryable
        status_int == 429 || status_int >= 500
      end

      sig { params(event: T::Hash[T.untyped, T.untyped], error_msg: String).returns(T.untyped) }
      def store_failed_event(event, error_msg)
        # Store in Redis for later inspection/retry
        # Using T.unsafe for Sidekiq.redis block and redis operations
        T.unsafe(Sidekiq).redis do |redis|
          T.unsafe(redis).rpush('langfuse:failed_events', {
            event: event,
            error: error_msg,
            timestamp: Time.now.utc.iso8601
          }.to_json)
        end
      end
    end
  end
end
