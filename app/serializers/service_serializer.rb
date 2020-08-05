class ServiceSerializer < ActiveModel::Serializer
  attributes :name, :public, :command, :cpu, :memory, :endpoint, :status, :deployed,
             :port_mappings, :running_count, :pending_count, :desired_count,
             :reverse_proxy_image, :hosts, :service_type, :force_ssl, :health_check

  belongs_to :heritage

  def port_mappings
    object.port_mappings.map do |pm|
      {
        container_port: pm.container_port,
        lb_port: pm.lb_port,
        host_port: pm.host_port,
        protocol: pm.protocol
      }
    end
  end

  def deployed
    object.deployment_finished?(nil)
  end
end
