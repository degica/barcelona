class ListenerSerializer < ActiveModel::Serializer
  attributes :endpoint, :health_check_interval, :health_check_timeout, :health_check_path,
             :healthy_threshold_count, :unhealthy_threshold_count

  def endpoint
    object.endpoint.name
  end
end
