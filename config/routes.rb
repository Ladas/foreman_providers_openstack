Rails.application.routes.draw do
  get 'new_action', to: 'foreman_providers_openstack/hosts#new_action'
end
