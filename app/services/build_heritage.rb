class BuildHeritage
  attr_accessor :params, :district, :heritage

  def initialize(_params, district: nil)
    params = _params.to_h.deep_dup
    heritage_name = params.delete(:id) || params[:name]
    @heritage = Heritage.find_or_initialize_by(name: heritage_name)
    @district = district || @heritage.district
    @params = convert_params_for_model params
  end

  def convert_params_for_model(new_params)
    if new_params[:services].present?
      new_params[:services_attributes] = new_params.delete(:services)
      new_params[:services_attributes].each do |service|
        service[:port_mappings_attributes] = service.delete(:port_mappings) if service[:port_mappings].present?

        unless service[:listeners].nil?
          endpoint_names = service[:listeners].map { |e| e[:endpoint] }
          endpoints = Endpoint.where(name: endpoint_names, district: @district).pluck(:name, :id)

          listener_map = Hash[endpoints]
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
      new_params[:environments_attributes] = sync_resources(
        new_params[:environments_attributes], heritage.environments, :name
      )
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

  def sync_resources(attributes, curr_attributes, resource_key)
    attr_map = curr_attributes.pluck(resource_key, :id).to_h
    attributes ||= []

    attributes.each do |attr|
      attr[:id] = attr_map[attr[resource_key]] if attr_map[attr[resource_key]].present?
    end

    resources_to_delete = attr_map.keys - attributes.map { |attr| attr[resource_key] }
    resources_to_delete.each do |k|
      attributes << {id: attr_map[k], _destroy: '1'}
    end
    attributes
  end

  def nullables
    [:cpu]
  end

  # This method sets fields defined in #nullables to nil before applying
  # updates to them, so that any deletions in barcelona.yml are detected
  # properly.
  def prenullify_params
    nullifiers = []
    heritage.services.each do |service|
      nuller_hash = {}
      nullables.each do |nullable|
        nuller_hash[nullable] = nil
      end
      nullifiers << { id: service.id, **nuller_hash }
    end
    {"services_attributes" => nullifiers}
  end

  def execute
    heritage.district = district if district.present?
    heritage.assign_attributes prenullify_params
    heritage.assign_attributes params
    heritage
  end
end
