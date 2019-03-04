class BuildHeritage
  attr_accessor :params, :district, :heritage

  def initialize(_params, district: nil)
    params = _params.to_h.deep_dup
    @district = district
    heritage_name = params.delete(:id) || params[:name]
    @heritage = Heritage.find_or_initialize_by(name: heritage_name)
    @params = convert_params_for_model params
  end

  def convert_params_for_model(new_params)
    if new_params[:services].present?
      new_params[:services_attributes] = new_params.delete(:services)
      new_params[:services_attributes].each do |service|
        service[:port_mappings_attributes] = service.delete(:port_mappings) if service[:port_mappings].present?

        unless service[:listeners].nil?
          listener_map = Hash[Endpoint.where(name: service[:listeners].map { |e| e[:endpoint] }).pluck(:name, :id)]
          service[:listeners_attributes] = service.delete(:listeners).map do |listener|
            {
              endpoint_id: listener_map[listener[:endpoint]],
              health_check_interval: listener[:health_check_interval],
              health_check_path: listener[:health_check_path],
              rule_priority: listener[:rule_priority],
              rule_conditions: listener[:rule_conditions]
            }
          end
        end
      end
    end

    if new_params[:environment]
      new_params[:environments_attributes] = new_params.delete(:environment).map do |e|
        e.slice(:name, :value, :value_from, :ssm_path)
      end
      new_params[:environments_attributes] = sync_resources(new_params[:environments_attributes], heritage.environments, :name)
    end


    unless heritage.new_record?
      new_params.delete :name

      if new_params[:services_attributes]
        new_params[:services_attributes] = sync_resources(new_params[:services_attributes], @heritage.services, :name)
        new_params[:services_attributes].each do |service|
          next if service[:_destroy].present? || service[:id].blank?
          service.delete :port_mappings_attributes

          service[:listeners_attributes] = sync_resources(service[:listeners_attributes],
                                                          Service.find(service[:id]).listeners,
                                                          :endpoint_id)
        end
      end
    end

    new_params
  end

  def sync_resources(attributes, resources, key_key)
    resource_map = resources.pluck(key_key, :id).to_h
    attributes ||= []
    attributes.each do |attr|
      attr[:id] = resource_map[attr[key_key]] if resource_map[attr[key_key]].present?
    end

    resources_to_delete = resource_map.keys - attributes.map { |attr| attr[key_key] }
    resources_to_delete.each do |k|
      attributes << {id: resource_map[k], _destroy: '1'}
    end
    attributes
  end

  def execute
    heritage.district = district if district.present?
    heritage.attributes = params
    heritage
  end
end
