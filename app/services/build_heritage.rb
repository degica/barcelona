class BuildHeritage
  attr_accessor :params, :district, :heritage

  def initialize(params, district: nil)
    @district = district
    heritage_name = params.delete(:id) || params[:name]
    @heritage = Heritage.find_or_initialize_by(name: heritage_name)
    @params = convert_params_for_model ActionController::Parameters.new(params)
  end

  def convert_params_for_model(original)
    new_params = original.dup
    if new_params[:env_vars].present?
      new_params[:env_vars_attributes] = new_params.delete(:env_vars).map do |k, v|
        existing = heritage.env_vars.find_by(key: k)
        e = {key: k, value: v}
        existing.present? ? e.merge(id: existing.id) : e
      end
    end

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
        new_params[:services_attributes].each do |service|
          service.delete :port_mappings_attributes # Currently updating port mapping is not supported
          name = service.delete :name
          service[:id] = map[name]
        end
      end
    end
    new_params
  end

  def execute
    heritage.district = district if district.present?
    heritage.attributes = params.permit!
    heritage
  end
end
