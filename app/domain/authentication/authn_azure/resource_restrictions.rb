module Authentication
  module AuthnAzure

    # This class represents the restrictions that are set on a Conjur host regarding
    # the Azure resources that it can authenticate with Conjur from.
    # It consists a list of AzureResource objects which represent the resource
    # restriction that need to be met in an authentication request.
    #
    # For example, if `resources` includes the AzureResource:
    #   - type: "subscription-id"
    #   - value: "some-subscription-id"
    #
    # then this Conjur host can authenticate with Conjur only with an Azure AD
    # token that was granted to an Azure resource that is part of the "some-subscription-id"
    # subscription
    class ResourceRestrictions

      attr_reader :resources

      def initialize(role_annotations:, service_id:, azure_resource_types:, logger:)
        @role_annotations = role_annotations
        @service_id       = service_id
        @azure_resource_types = azure_resource_types
        @logger           = logger

        init_resources
      end

      private

      def init_resources
        @resources = @azure_resource_types.each_with_object([]) do |resource_type, resources|
          resource_value = resource_value(resource_type)
          if resource_value
            resources.push(
              AzureResource.new(
                type: resource_type,
                value: resource_value
              )
            )
          end
        end
      end

      # check the `service-id` specific resource first to be more granular
      def resource_value resource_type
        annotation_value("authn-azure/#{@service_id}/#{resource_type}") ||
          annotation_value("authn-azure/#{resource_type}")
      end

      def annotation_value name
        annotation = @role_annotations.find { |a| a.values[:name] == name }

        # return the value of the annotation if it exists, nil otherwise
        if annotation
          @logger.debug(LogMessages::Authentication::RetrievedAnnotationValue.new(name))
          annotation[:value]
        end
      end
    end
  end
end