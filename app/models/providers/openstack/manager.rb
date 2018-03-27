module Providers
  class Openstack::Manager < ExtManagementSystem
    include ForemanProviders::Logging

    include Cloud::Associations
    include ManagerMixin

    def disconnects
      instances
    end

    alias_attribute :address, :hostname
  end
end
