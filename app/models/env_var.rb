class EnvVar < ActiveRecord::Base
  include EncryptAttribute

  delegate :district, to: :heritage

  belongs_to :heritage

  validates :key, uniqueness: {scope: :heritage_id}, presence: true
  validates :value, presence: true, unless: :secret?

  encrypted_attribute :value, secret_key: ENV['ENCRYPTION_KEY']

  before_save   :sync_s3,        if: :secret?
  before_save   :wipe_value,     if: :secret?
  after_destroy :delete_from_s3, if: :secret?

  def value_with_to_s
    value_without_to_s.to_s
  end
  alias_method_chain :value, :to_s

  def s3_path
    "heritages/#{heritage.name}/env/#{key}"
  end

  private

  def sync_s3
    if secret?
      district.aws.s3.put_object(bucket: district.s3_bucket_name,
                                 key: s3_path,
                                 body: value,
                                 server_side_encryption: "aws:kms")
    else
      delete_from_s3 unless new_record?
    end
  end

  def delete_from_s3
    district.aws.s3.delete_object(bucket: district.s3_bucket_name, key: s3_path)
  end

  def wipe_value
    self.value = nil if secret?
  end
end
