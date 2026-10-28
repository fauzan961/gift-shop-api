class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed

  private
    def render_not_found(exception)
      render json: { error: { code: "not_found", message: "#{exception.model || "Record"} not found" } },
             status: :not_found
    end

    def render_validation_failed(exception)
      details = exception.record.errors.to_hash.transform_keys { |attribute| attribute.to_s.camelize(:lower) }

      render json: { error: { code: "validation_failed", message: exception.message, details: details } },
             status: :unprocessable_content
    end
end
