require 'util/miq-exception'

module Providers::Openstack::ManagerMixin
  extend ActiveSupport::Concern

  included do
    after_save :stop_event_monitor_queue_on_change
    before_destroy :stop_event_monitor
  end

  alias_attribute :keystone_v3_domain_id, :uid_ems

  #
  # OpenStack interactions
  #
  module ClassMethods
    def raw_connect(password, params, service = "Compute")
      ems = new
      ems.name                   = params[:name].strip
      ems.provider_region        = params[:provider_region]
      ems.api_version            = params[:api_version].strip
      ems.security_protocol      = params[:default_security_protocol].strip
      ems.keystone_v3_domain_id  = params[:keystone_v3_domain_id]

      user, hostname, port = params[:default_userid], params[:default_hostname].strip, params[:default_api_port].strip

      endpoint = {:role => :default, :hostname => hostname, :port => port, :security_protocol => ems.security_protocol}
      authentication = {:userid => user, :password => MiqPassword.try_decrypt(password), :save => false, :role => 'default', :authtype => 'default'}
      ems.connection_configurations = [{:endpoint       => endpoint,
                                        :authentication => authentication}]

      begin
        ems.connect(:service => service)
      rescue => err
        miq_exception = translate_exception(err)
        raise unless miq_exception

        _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
        raise miq_exception
      end
    end

    #
    # class MiqException::InvalidCredentialsError < Error; end
    # class MiqException::UnreachableError < Error; end
    # class MiqException::HostError < Error; end
    # class MiqException::InvalidCredentialsError < Error; end
    # class MiqException::HostError < Error; end
    # class MiqException::InvalidCredentialsError < Error; end
    # class MiqException::EVMLoginError < Error; end


    def translate_exception(err)
      require 'excon'
      case err
      when Excon::Errors::Unauthorized
        MiqException::InvalidCredentialsError.new("Login failed due to a bad username or password.")
      when Excon::Errors::Timeout
        MiqException::UnreachableError.new("Login attempt timed out")
      when Excon::Errors::SocketError
        MiqException::HostError.new("Socket error: #{err.message}")
      when MiqException::InvalidCredentialsError, MiqException::HostError
        err
      else
        MiqException::EVMLoginError.new("Unexpected response returned from system: #{err.message}")
      end
    end
  end

  def auth_url
    self.class.auth_url(address, port)
  end

  def browser_url
    "http://#{address}/dashboard"
  end

  def openstack_handle(options = {})
    require 'providers/openstack/legacy/openstack_handle'
    @openstack_handle ||= begin
      raise MiqException::InvalidCredentialsError, "No credentials defined" if self.missing_credentials?(options[:auth_type])

      username = options[:user] || authentication_userid(options[:auth_type])
      password = options[:pass] || authentication_password(options[:auth_type])

      extra_options = {
        :ssl_ca_file    => nil, # ::Settings.ssl.ssl_ca_file,
        :ssl_ca_path    => nil, #::Settings.ssl.ssl_ca_path,
        :ssl_cert_store => OpenSSL::X509::Store.new
      }
      extra_options[:domain_id]         = keystone_v3_domain_id
      extra_options[:region]            = provider_region if provider_region.present?
      extra_options[:omit_default_port] = true # ::Settings.ems.ems_openstack.excon.omit_default_port
      extra_options[:read_timeout]      = 60 # ::Settings.ems.ems_openstack.excon.read_timeout

      osh = OpenstackHandle::Handle.new(username, password, address, port, api_version, security_protocol, extra_options)
      # osh.connection_options = {:instrumentor => $fog_log}
      osh
    end
  end

  def reset_openstack_handle
    @openstack_handle = nil
  end

  def connect(options = {})
    openstack_handle(options).connect(options)
  end

  def connect_volume
    connect(:service => "Volume")
  end

  def connect_identity
    connect(:service => "Identity")
  end

  def event_monitor_options
    @event_monitor_options ||= begin
      opts = {:ems => self, :automatic_recovery => false, :recover_from_connection_close => false}

      ceilometer = connection_configuration_by_role("ceilometer")

      if ceilometer.try(:endpoint) && !ceilometer.try(:endpoint).try(:marked_for_destruction?)
        opts[:events_monitor] = :ceilometer
      elsif (amqp = connection_configuration_by_role("amqp"))
        opts[:events_monitor] = :amqp
        if (endpoint = amqp.try(:endpoint))
          opts[:hostname]          = endpoint.hostname
          opts[:port]              = endpoint.port
          opts[:security_protocol] = endpoint.security_protocol
        end

        if (authentication = amqp.try(:authentication))
          opts[:username] = authentication.userid
          opts[:password] = authentication.password
        end
      end
      opts
    end
  end

  def event_monitor_available?
    false
  end

  def sync_event_monitor_available?
    false
  end

  def stop_event_monitor_queue_on_change
  end

  def stop_event_monitor_queue_on_credential_change
    # TODO(lsmola) this check should not be needed. Right now we are saving each individual authentication and
    # it is breaking the check for changes. We should have it all saved by autosave when saving EMS, so the code
    # for authentications needs to be rewritten.
    stop_event_monitor_queue_on_change
  end

  def translate_exception(err)
    self.class.translate_exception(err)
  end

  def verify_api_credentials(options = {})
    options[:service] = "Compute"
    with_provider_connection(options) {}
    true
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_api_credentials

  def verify_amqp_credentials(_options = {})
    # require 'providers/openstack/legacy/openstack_event_monitor'
    OpenstackEventMonitor.test_amqp_connection(event_monitor_options)
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_amqp_credentials

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    raise MiqException::HostError, "No credentials defined" if self.missing_credentials?(auth_type)

    options[:auth_type] = auth_type
    case auth_type.to_s
    when 'default' then verify_api_credentials(options)
    when 'amqp' then    verify_amqp_credentials(options)
    else;           raise "Invalid OpenStack Authentication Type: #{auth_type.inspect}"
    end
  end

  def required_credential_fields(_type)
    [:userid, :password]
  end

  def orchestration_template_validate(template)
    openstack_handle.orchestration_service.templates.validate(:template => template.content)
    nil
  rescue Excon::Errors::BadRequest => bad
    JSON.parse(bad.response.body)['error']['message']
  rescue => err
    _log.error "template=[#{template.name}], error: #{err}"
    raise MiqException::OrchestrationValidationError, err.to_s, err.backtrace
  end

  delegate :description, :to => :class
end