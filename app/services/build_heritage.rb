class BuildHeritage
  attr_accessor :params, :district, :heritage

  def initialize(params, district: nil)
    @district = district
    heritage_name = params.delete(:id) || params[:name]
    @heritage = Heritage.find_or_initialize_by(name: heritage_name)
    @params = convert_params_for_model params.to_h
  end

  def convert_params_for_model(original)
    new_params = original.dup

    if new_params[:services].present?
      new_params[:services_attributes] = new_params.delete(:services)
      new_params[:services_attributes].each do |service|
        service[:port_mappings_attributes] = service.delete(:port_mappings) if service[:port_mappings].present?

        if service[:endpoints].present?
          endpoint_map = Hash[Endpoint.where(name: service[:endpoints].map { |e| e[:name] }).pluck(:name, :id)]
          service[:listeners_attributes] = service.delete(:endpoints).map do |endpoint|
            {
              endpoint_id: endpoint_map[endpoint[:name]],
              health_check_interval: endpoint[:health_check_interval],
              health_check_path: endpoint[:health_check_path],
              rule_priority: endpoint[:rule_priority],
              rule_conditions: endpoint[:rule_conditions]
            }
          end
        end
      end
    end

    unless heritage.new_record?
      new_params.delete :name

      map = Hash[@heritage.services.pluck(:name, :id)]
      if new_params[:services_attributes].present?
        # Add or modify services
        new_params[:services_attributes].each do |service|
          service.delete :port_mappings_attributes # Currently updating port mapping is not supported
          name = service[:name] or raise "name is required"
          if map[name].present?
            service[:id] = map[name]
            listeners_map = Hash[Service.find(service[:id]).listeners.pluck("endpoint_id", "id")]
            service[:listeners_attributes] ||= []
            service[:listeners_attributes].each do |listener|
              listener[:id] = listeners_map[listener[:endpoint_id]] if listener[:endpoint_id].present?
            end

            listeners_to_delete = listeners_map.keys - service[:listeners_attributes].map { |l| l[:endpoint_id] }
            listeners_to_delete.each do |endpoint_id|
              service[:listeners_attributes] << {
                id: listeners_map[endpoint_id],
                _destroy: '1'
              }
            end
          end
        end

        # Delete services
        to_delete = map.keys - new_params[:services_attributes].map{ |s| s[:name] }
        to_delete.each do |name|
          new_params[:services_attributes] << {
            id: map[name],
            _destroy: '1'
          }
        end
      end
    end

    new_params
  end

  def execute
    heritage.district = district if district.present?
    heritage.attributes = params
    heritage
  end
end
