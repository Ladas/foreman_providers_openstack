module ForemanProvidersOpenstack
  # Example: Plugin's HostsController inherits from Foreman's HostsController
  class HostsController < ::HostsController
    # change layout if needed
    # layout 'foreman_providers_openstack/layouts/new_layout'

    def new_action
      # automatically renders view/foreman_providers_openstack/hosts/new_action
    end
  end
end
