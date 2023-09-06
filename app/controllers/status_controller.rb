class StatusController < ActionController::Base

  def index
    @districts = District.all
  end

  def show
    @objtype = 'district'
    objid = params[:id]

    if objid == 'jobs'
      return show_jobs

    elsif params[:objid]
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

  def show_jobs
    render 'show_jobs'
  end
end
