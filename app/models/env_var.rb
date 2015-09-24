class EnvVar < ActiveRecord::Base
  belongs_to :heritage

  validates :key, uniqueness: {scope: :heritage_id}
end
