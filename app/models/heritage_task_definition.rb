class HeritageTaskDefinition
  attr_accessor :heritage, :cpu, :memory, :family_name, :command, :port_mappings, :container_defintions, :force_ssl, :hosts, :reverse_proxy_image
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
        reverse_proxy_image: service.reverse_proxy_image)
  end

  def self.oneoff_definition(oneoff)
    new(heritage: oneoff.heritage,
        family_name: "#{oneoff.heritage.name}-oneoff",
        cpu: 128,
        memory: 512)
  end

  def to_task_definition
    containers = [container_definition]
    containers << reverse_proxy_definition if web_service?
    {family: family_name, container_definitions: containers}
  end

  private

  def initialize(heritage:, family_name:, cpu:, memory:, command: nil, port_mappings: nil, is_web_service: false, force_ssl: false, hosts: [], reverse_proxy_image: nil)
    @heritage = heritage
    @family_name = family_name
    @cpu = cpu
    @memory = memory
    @command = command
    @port_mappings = port_mappings
    @is_web_service = is_web_service
    @force_ssl = force_ssl
    @hosts = hosts
    @reverse_proxy_image = reverse_proxy_image
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

    base = base.merge(
      cpu: cpu,
      memory: memory
    ).compact
    base[:command] = LaunchCommand.new(command).to_command if command.present?
    base[:port_mappings] = port_mappings.to_task_definition if port_mappings.present?
    base
  end

  def reverse_proxy_definition
    base = heritage.base_task_definition("#{family_name}-revpro")
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
end
