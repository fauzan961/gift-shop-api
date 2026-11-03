class ApplicationController < ActionController::API
  include Authentication

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed

  private
    def render_error(status, code, message, **extra)
      render json: { error: { code: code, message: message, **extra } }, status: status
    end

    def render_too_many_requests(retry_after, message)
      response.headers["Retry-After"] = retry_after.to_s
      render_error(:too_many_requests, "too_many_requests", message, retryAfter: retry_after)
    end

    def render_not_found(exception)
      render_error(:not_found, "not_found", "#{exception.model || "Record"} not found")
    end

    def render_validation_failed(exception)
      details = exception.record.errors.to_hash.transform_keys { |attribute| attribute.to_s.camelize(:lower) }

      render json: { error: { code: "validation_failed", message: exception.message, details: details } },
             status: :unprocessable_content
    end
end
