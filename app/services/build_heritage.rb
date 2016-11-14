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
          service[:id] = map[name] if map[name].present?
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
