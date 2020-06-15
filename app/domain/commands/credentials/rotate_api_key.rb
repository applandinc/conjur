# frozen_string_literal: true

require 'command_class'

module Commands
  module Credentials

    # In might seem unnecessary to move this behavior into a command class.
    # However, we factor this out now to prepare for A) adding audit decorations
    # to this operation, and B) those audit events including the requestor's
    # client IP address, which will be an input to this CommandClass, rather than
    # to the Credential model's method.
    RotateApiKey ||= CommandClass.new(
      dependencies: {
        audit_log: ::Audit.logger
      },
      inputs: %i(role_to_rotate authenticated_role)
    ) do

      def call
        rotate_api_key
        audit_success
      rescue => e
        audit_failure(e)
        raise e
      end

      private

      def rotate_api_key
        credentials.rotate_api_key
        credentials.save
      end

      def credentials
        @role_to_rotate.credentials
      end

      def audit_success
        @audit_log.log(
          ::Audit::Event::ApiKey.new(
            auth_role: @authenticated_role,
            subject_role: @role_to_rotate,
            success: true
          )
        )
      end

      def audit_failure(err)
        @audit_log.log(
          ::Audit::Event::ApiKey.new(
            auth_role: @authenticated_role,
            subject_role: @role_to_rotate,
            success: false,
            error_message: err.message
          )
        )
      end
    end
  end
end
