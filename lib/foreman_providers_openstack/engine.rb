module ForemanProvidersOpenstack
  class Engine < ::Rails::Engine
    engine_name 'foreman_providers_openstack'

    config.autoload_paths += Dir["#{config.root}/app/controllers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/helpers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/overrides"]

    # Add any db migrations
    initializer 'foreman_providers_openstack.load_app_instance_data' do |app|
      ForemanProvidersOpenstack::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_providers_openstack.register_plugin', :before => :finisher_hook do |_app|
      require 'extensions/descendant_loader'
      # make sure STI models are recognized
      DescendantLoader.instance.descendants_paths << config.root.join('app')

      Foreman::Plugin.register :foreman_providers_openstack do
        requires_foreman '>= 1.4'

        # Add permissions
        security_block :foreman_providers_openstack do
          permission :view_foreman_providers_openstack, :'foreman_providers_openstack/hosts' => [:new_action]
        end

        # Add a new role called 'Discovery' if it doesn't exist
        role 'ForemanProvidersOpenstack', [:view_foreman_providers_openstack]

        # add menu entry
        menu :top_menu, :template,
             url_hash: { controller: :'foreman_providers_openstack/hosts', action: :new_action },
             caption: 'ForemanProvidersOpenstack',
             parent: :hosts_menu,
             after: :hosts

        # add dashboard widget
        widget 'foreman_providers_openstack_widget', name: N_('Foreman plugin template widget'), sizex: 4, sizey: 1
      end
    end

    # Precompile any JS or CSS files under app/assets/
    # If requiring files from each other, list them explicitly here to avoid precompiling the same
    # content twice.
    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end
    initializer 'foreman_providers_openstack.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end
    initializer 'foreman_providers_openstack.configure_assets', group: :assets do
      SETTINGS[:foreman_providers_openstack] = { assets: { precompile: assets_to_precompile } }
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      begin
        Host::Managed.send(:include, ForemanProvidersOpenstack::HostExtensions)
        HostsHelper.send(:include, ForemanProvidersOpenstack::HostsHelperExtensions)
      rescue => e
        Rails.logger.warn "ForemanProvidersOpenstack: skipping engine hook (#{e})"
      end
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanProvidersOpenstack::Engine.load_seed
      end
    end

    initializer 'foreman_providers_openstack.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../../..', __FILE__), 'locale')
      locale_domain = 'foreman_providers_openstack'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
