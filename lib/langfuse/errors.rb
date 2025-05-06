# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module Langfuse
  # Base error class for all Langfuse-related errors
  class Error < StandardError; end

  # Error related to API communication issues
  class APIError < Error
    extend T::Sig

    sig { returns(T.nilable(Integer)) }
    attr_reader :status_code

    sig { returns(T.nilable(String)) }
    attr_reader :response_body

    sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    attr_reader :request_details

    sig do
      params(
        message: T.nilable(String),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, status_code: nil, response_body: nil, request_details: nil)
      @status_code = status_code
      @response_body = response_body
      @request_details = request_details
      super(message)
    end
  end

  # Error related to configuration issues
  class ConfigurationError < APIError
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :config_key

    sig do
      params(
        message: T.nilable(String),
        config_key: T.nilable(String),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, config_key: nil, status_code: nil, response_body: nil, request_details: nil)
      @config_key = config_key
      super(message, status_code: status_code, response_body: response_body, request_details: request_details)
    end
  end

  # Error related to authentication or authorization issues
  class AuthenticationError < APIError
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :credentials_info

    sig do
      params(
        message: T.nilable(String),
        credentials_info: T.nilable(String),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, credentials_info: nil, status_code: nil, response_body: nil, request_details: nil)
      @credentials_info = credentials_info
      super(message, status_code: status_code, response_body: response_body, request_details: request_details)
    end
  end

  # Error related to rate limiting
  class RateLimitError < APIError
    extend T::Sig

    sig { returns(T.nilable(Integer)) }
    attr_reader :retry_after

    sig do
      params(
        message: T.nilable(String),
        retry_after: T.nilable(Integer),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, retry_after: nil, status_code: nil, response_body: nil, request_details: nil)
      @retry_after = retry_after
      super(message, status_code: status_code, response_body: response_body, request_details: request_details)
    end
  end

  # Error that can be retried
  class RetryableError < APIError
    extend T::Sig

    sig { returns(T.nilable(Integer)) }
    attr_reader :suggested_retry_delay

    sig do
      params(
        message: T.nilable(String),
        suggested_retry_delay: T.nilable(Integer),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, suggested_retry_delay: nil, status_code: nil, response_body: nil, request_details: nil)
      @suggested_retry_delay = suggested_retry_delay
      super(message, status_code: status_code, response_body: response_body, request_details: request_details)
    end
  end

  # Error related to validation issues
  class ValidationError < APIError
    extend T::Sig

    sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
    attr_reader :validation_details

    sig do
      params(
        message: T.nilable(String),
        validation_details: T.nilable(T::Hash[Symbol, T.untyped]),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, validation_details: nil, status_code: nil, response_body: nil, request_details: nil)
      @validation_details = validation_details
      super(message, status_code: status_code, response_body: response_body, request_details: request_details)
    end
  end

  # Error when a resource is not found
  class NotFoundError < APIError
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :resource_id

    sig { returns(T.nilable(String)) }
    attr_reader :resource_type

    sig do
      params(
        message: T.nilable(String),
        resource_id: T.nilable(String),
        resource_type: T.nilable(String),
        status_code: T.nilable(Integer),
        response_body: T.nilable(String),
        request_details: T.nilable(T::Hash[Symbol, T.untyped])
      ).void
    end
    def initialize(message = nil, resource_id: nil, resource_type: nil, status_code: nil, response_body: nil, request_details: nil)
      @resource_id = resource_id
      @resource_type = resource_type
      super(message, status_code: status_code, response_body: response_body, request_details: request_details)
    end
  end
end
