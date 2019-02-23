class HeritageTaskDefinition
  attr_accessor :heritage, :user, :cpu, :memory, :family_name, :command, :port_mappings, :container_defintions, :force_ssl, :hosts, :reverse_proxy_image, :mode
  delegate :district, to: :heritage

  def self.service_definition(service)
    new(heritage: service.heritage,
        family_name: service.service_name,
        cpu: service.cpu,
        memory: service.memory,
        command: service.command,
        port_mappings: service.port_mappings,
        is_web_service: service.web?,
        force_ssl: service.force_ssl,
        hosts: service.hosts,
        reverse_proxy_image: service.reverse_proxy_image,
        mode: (service.listeners.present?) ? :alb : :tcp
       )
  end

  def self.oneoff_definition(oneoff)
    new(heritage: oneoff.heritage,
        family_name: "#{oneoff.heritage.name}-oneoff",
        app_container_labels: {
          "com.barcelona.oneoff-id" => oneoff.session_token
        }.compact,
        cpu: 128,
        memory: oneoff.memory,
        user: oneoff.user
       )
  end

  def self.schedule_definition(heritage)
    new(heritage: heritage,
        family_name: "#{heritage.name}-schedule",
        cpu: 128,
        memory: 512)
  end

  def to_task_definition(without_task_role: false, camelize: false)
    containers = [container_definition, run_pack_definition]
    if web_service?
      containers << case mode
                    when :tcp
                      reverse_proxy_definition_tcp
                    when :alb
                      reverse_proxy_definition_alb
                    end
    end
    ret = {family: family_name, container_definitions: containers}
    ret = ret.merge(task_role_arn: heritage.task_role_id, execution_role_arn: heritage.task_execution_role_id) unless without_task_role
    if camelize
      ret = deep_transform_keys_with_parent_keys(ret) do |k, parents|
        (parents.last(2) != [:log_configuration, :options] &&
         parents.last != [:docker_labels]
        ) ? k.to_s.camelize : k
      end
    end
    ret
  end

  private

  def deep_transform_keys_with_parent_keys(object, parents=[], &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key, parents)] = deep_transform_keys_with_parent_keys(value, parents + [key], &block)
      end
    when Array
      object.map.with_index {|e, i| deep_transform_keys_with_parent_keys(e, parents + [i], &block) }
    else
      object
    end
  end

  def initialize(heritage:, family_name:, user: nil, cpu:, memory:, command: nil, port_mappings: nil, is_web_service: false, force_ssl: false, hosts: [], app_container_labels: {}, reverse_proxy_image: nil, mode: nil)
    @heritage = heritage
    @family_name = family_name
    @user = user
    @cpu = cpu
    @memory = memory
    @command = command
    @port_mappings = port_mappings
    @is_web_service = is_web_service
    @force_ssl = force_ssl
    @hosts = hosts
    @reverse_proxy_image = reverse_proxy_image
    @app_container_labels = app_container_labels
    @mode = mode
  end

  def web_service?
    @is_web_service
  end

  def web_container_port
    3000
  end

  def container_definition
    base = heritage.base_task_definition(family_name)
    if port_mappings.present?
      base[:environment] += port_mappings.map do |pm|
        {
          name: "HOST_PORT_#{pm.protocol.upcase}_#{pm.container_port}",
          value: pm.host_port.to_s
        }
      end
    end

    if web_service?
      base[:environment] << {
        name: "PORT",
        value: web_container_port.to_s
      }
    end

    base[:docker_labels] = @app_container_labels if @app_container_labels.present?

    base = base.merge(
      cpu: cpu,
      memory: memory,
      volumes_from: [
        {
          source_container: "runpack",
          read_only: true
        }
      ]
    ).compact
    base[:command] = LaunchCommand.new(heritage, command).to_command if command.present?
    base[:port_mappings] = port_mappings.to_task_definition if port_mappings.present?
    base[:user] = user if user.present?
    base
  end

  def run_pack_definition
    base = heritage.base_task_definition("runpack", with_environment: false)
    base.merge(
      cpu: 1,
      memory: 16,
      essential: false,
      image: "quay.io/degica/barcelona-run-pack"
    )
  end

  def reverse_proxy_definition_tcp
    base = heritage.base_task_definition("#{family_name}-revpro", with_environment: false)
    base[:environment] += [
      {name: "AWS_REGION", value: district.region},
      {name: "UPSTREAM_NAME", value: "backend"},
      {name: "UPSTREAM_PORT", value: web_container_port.to_s},
      {name: "FORCE_SSL", value: (!!force_ssl).to_s},
      hosts.map do |h|
        host_key = h['hostname'].tr('.', '_').gsub('-', '__').upcase
        [
          {name: "CERT_#{host_key}", value: h['ssl_cert_path']},
          {name: "KEY_#{host_key}", value: h['ssl_key_path']}
        ]
      end
    ].flatten

    http_hosts = hosts.map{ |h| h['hostname'] }.join(',')
    base[:environment] << {name: "HTTP_HOSTS", value: http_hosts} if http_hosts.present?

    http = port_mappings.http
    https = port_mappings.https
    base.merge(
      cpu: 128,
      memory: 128,
      image: reverse_proxy_image,
      links: ["#{family_name}:backend"],
      port_mappings: [
        {
          container_port: 80,
          host_port: http.host_port,
          protocol: "tcp"
        },
        {
          container_port: 443,
          host_port: https.host_port,
          protocol: "tcp"
        }
      ]
    )
  end

  def reverse_proxy_definition_alb
    base = heritage.base_task_definition("#{family_name}-revpro", with_environment: false)
    base[:environment] += [
      {name: "AWS_REGION", value: district.region},
      {name: "UPSTREAM_NAME", value: "backend"},
      {name: "UPSTREAM_PORT", value: web_container_port.to_s},
      {name: "DISABLE_PROXY_PROTOCOL", value: "true"},
      {name: "FORCE_SSL", value: (!!force_ssl).to_s},
      {name: "ALB", value: "true"}
    ].flatten

    base.merge(
      cpu: 128,
      memory: 128,
      image: reverse_proxy_image,
      links: ["#{family_name}:backend"],
      port_mappings: [
        {
          container_port: 80,
          protocol: "tcp"
        }
      ]
    )
  end
end
