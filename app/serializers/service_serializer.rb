class ServiceSerializer < ActiveModel::Serializer
  attributes :name, :command, :cpu, :memory, :load_balancer, :status, :slack_url

  belongs_to :heritage

  def load_balancer
    lb = object.fetch_load_balancer
    if lb.nil?
      nil
    else
      {
        name: lb.load_balancer_name,
        dns_name: lb.dns_name
      }
    end
  end
end
