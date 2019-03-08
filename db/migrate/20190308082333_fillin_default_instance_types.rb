class FillinDefaultInstanceTypes < ActiveRecord::Migration[5.2]
  def change
    District.transaction do
      District.all.each do |d|
        d.update!(auto_scaling_instance_types: [d.cluster_instance_type])
      end
    end
  end
end
