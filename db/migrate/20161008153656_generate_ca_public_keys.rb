class GenerateCaPublicKeys < ActiveRecord::Migration
  def change
    District.all.each do |d|
      ApplyDistrict.new(d).generate_ssh_ca_key_pair
      d.save!
    end
  end
end
