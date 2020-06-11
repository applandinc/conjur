module Audit
  module Event
    class ApiKey

      def initialize(auth_role:, subject_role:, success:, error_message: nil)
        @auth_role = auth_role
        @subject_role = subject_role
        @success = success
        @error_message = error_message
      end

      # :reek:UtilityFunction
      def progname
        Event.progname
      end

      def severity
        attempted_action.severity
      end

      def to_s
        message
      end

      def message
        attempted_action.message(
          success_msg: success_message,
          failure_msg: failure_message,
          error_msg: @error_message
        )
      end

      def message_id
        'api-key'
      end

      def structured_data
        {
          SDID::AUTH => { user: @auth_role.id },
          SDID::SUBJECT => { role: @subject_role.id }
        }.merge(
          attempted_action.action_sd
        )
      end

      def facility
        # Security or authorization messages which should be kept private. See:
        # https://github.com/ruby/ruby/blob/master/ext/syslog/syslog.c#L109
        # Note: Changed this to from LOG_AUTH to LOG_AUTHPRIV because the former
        # is deprecated.
        Syslog::LOG_AUTHPRIV
      end

      private

      # It's clearer to simply call the #id attribute multiple times, rather
      # than factor it out, even though it reeks of :reek:DuplicateMethodCall
      def success_message
        if own_key?
          "#{@auth_role.id} successfully rotated their API key"
        else
          "#{@auth_role.id} successfully rotated the api key for #{@subject_role.id}"
        end
      end

      # It's clearer to simply call the #id attribute multiple times, rather
      # than factor it out, even though it reeks of :reek:DuplicateMethodCall
      def failure_message
        if own_key?
          "#{@auth_role.id} failed to rotate their API key"
        else
          "#{@auth_role.id} failed to rotate the api key for #{@subject_role.id}"
        end
      end
      
      # True if the role requesting the rotation is the same role
      # the rotation is for. In other words, when you rotate your own
      # API key
      def own_key?
        @auth_role.id == @subject_role.id
      end

      def attempted_action
        @attempted_action ||= AttemptedAction.new(
          success: @success,
          operation: 'rotate'
        )
      end
    end
  end
end
