class StatusController < ActionController::Base

  def index
    @districts = District.all
  end

  def show
    @objtype = 'district'
    objid = params[:id]

    if params[:objid]
      @objtype = params[:status_id]
      objid = params[:objid]
    end

    cls = @objtype.camelize.safe_constantize

    if cls.nil?
      raise ActiveRecord::RecordNotFound
    end

    @obj = cls.find_by_id(objid)

    if @obj.nil?
      raise ActiveRecord::RecordNotFound
    end
  end
end
