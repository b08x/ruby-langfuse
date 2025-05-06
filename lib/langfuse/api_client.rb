# frozen_string_literal: true
# typed: strict

require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'sorbet-runtime'

module Langfuse
  class ApiClient
    extend T::Sig

    sig { returns(T.untyped) }
    attr_reader :config

    sig { params(config: T.untyped).void }
    def initialize(config)
      @config = config
    end

    sig { params(events: T::Array[T::Hash[T.untyped, T.untyped]]).returns(T::Hash[String, T.untyped]) }
    def ingest(events)
      uri = URI.parse("#{@config.host}/api/public/ingestion")

      # Build the request
      request = Net::HTTP::Post.new(uri.path)
      request.content_type = 'application/json'

      # Set authorization header using base64 encoded credentials
      auth = Base64.strict_encode64("#{@config.public_key}:#{@config.secret_key}")
      # Log the encoded auth header for debugging
      if @config.debug
        log("Using auth header: Basic #{auth} (public_key: #{@config.public_key}, secret_key: #{@config.secret_key})")
      end
      request['Authorization'] = "Basic #{auth}"

      # Set the payload
      request.body = {
        batch: events
      }.to_json

      # Send the request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 10 # 10 seconds

      if @config.debug
        log("Sending #{events.size} events to Langfuse API at #{@config.host}")
        log("Events: #{events.inspect}")
        # log("Using auth header: Basic #{auth.gsub(/.(?=.{4})/, '*')}") # Mask most of the auth token
        log("Using auth header: Basic #{auth}") # Mask most of the auth token
        log("Request url: #{uri}")
      end

      log('---') # Moved log statement before response handling to avoid affecting return value

      response = http.request(request)

      result = T.let(nil, T.nilable(T::Hash[String, T.untyped]))

      case response.code.to_i
      when 200..299
        log("Received successful response: #{response.code}") if @config.debug
        result = JSON.parse(response.body)
      when 207 # Partial success
        log('Received 207 partial success response') if @config.debug
        result = JSON.parse(response.body)
      when 401, 403
        raise AuthenticationError.new(
          "Authentication failed: #{response.message}",
          credentials_info: "public_key: #{@config.public_key}",
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      when 404
        # Extract resource info from response if possible
        resource_info = extract_resource_info(response.body)

        raise NotFoundError.new(
          "Resource not found: #{response.message}",
          resource_id: resource_info[:id],
          resource_type: resource_info[:type],
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      when 422
        # Extract validation details if possible
        validation_details = extract_validation_details(response.body)

        raise ValidationError.new(
          "Validation error: #{response.message}",
          validation_details: validation_details,
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      when 429
        retry_after = response['Retry-After']&.to_i
        raise RateLimitError.new(
          "Rate limit exceeded. Retry after #{retry_after || 'unknown'} seconds.",
          retry_after: retry_after,
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      when 400..499
        raise APIError.new(
          "API client error: #{response.code} #{response.message}",
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      when 500..599
        raise RetryableError.new(
          "API server error: #{response.code} #{response.message}",
          suggested_retry_delay: 30, # Suggest a 30 second retry delay for server errors
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      else
        raise APIError.new(
          "Unexpected API response: #{response.code} #{response.message}",
          status_code: response.code.to_i,
          response_body: response.body,
          request_details: { url: uri.to_s, method: 'POST' }
        )
      end

      result
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise RetryableError.new(
        "Request timeout: #{e.message}",
        suggested_retry_delay: 5, # Suggest a 5 second retry delay for timeouts
        request_details: { url: uri.to_s, method: 'POST' }
      )
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
      raise RetryableError.new(
        "Connection error: #{e.message}",
        suggested_retry_delay: 10, # Suggest a 10 second retry delay for connection errors
        request_details: { url: uri.to_s, method: 'POST' }
      )
    rescue JSON::ParserError => e
      raise APIError.new(
        "Invalid JSON response: #{e.message}",
        response_body: response&.body,
        request_details: { url: uri.to_s, method: 'POST' }
      )
    rescue StandardError => e
      log("Error during API request: #{e.message}", :error)
      raise
    end

    private

    sig { params(message: String, level: Symbol).returns(T.untyped) }
    def log(message, level = :debug)
      return unless @config.debug

      T.unsafe(@config.logger).send(level, "[Langfuse] #{message}")
    end

    sig { params(response_body: T.nilable(String)).returns(T::Hash[Symbol, T.nilable(String)]) }
    def extract_resource_info(response_body)
      return { id: nil, type: nil } if response_body.nil?

      begin
        data = JSON.parse(response_body)
        id = data['id'] || data['resourceId']
        type = data['type'] || data['resourceType']
        { id: id, type: type }
      rescue JSON::ParserError
        { id: nil, type: nil }
      end
    end

    sig { params(response_body: T.nilable(String)).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    def extract_validation_details(response_body)
      return nil if response_body.nil?

      begin
        data = JSON.parse(response_body)
        details = data['errors'] || data['validationErrors'] || data['details']
        details.is_a?(Hash) ? details.transform_keys(&:to_sym) : nil
      rescue JSON::ParserError
        nil
      end
    end
  end
end
