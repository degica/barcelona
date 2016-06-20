class BuildApp
  attr_accessor :params, :district, :app

  def initialize(params, district: nil)
    @district = district
    app_name = params.delete(:id) || params[:name]
    @app = App.find_or_initialize_by(name: app_name)
    @params = convert_params_for_model ActionController::Parameters.new(params)
  end

  def convert_params_for_model(original)
    new_params = original.dup
    if new_params[:env_vars].present?
      new_params[:env_vars_attributes] = new_params.delete(:env_vars).map do |k, v|
        existing = app.env_vars.find_by(key: k)
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

    unless app.new_record?
      new_params.delete :name

      map = Hash[@app.services.pluck(:name, :id)]
      if new_params[:services_attributes].present?
        # Add or modify services
        new_params[:services_attributes].each do |service|
          service.delete :port_mappings_attributes # Currently updating port mapping is not supported
          name = service.require :name
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
    app.district = district if district.present?
    app.attributes = params.permit!
    app
  end
end
