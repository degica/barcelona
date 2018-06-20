class EnvVar < ActiveRecord::Base
  module ValueToString
    def value
      super.to_s
    end
  end

  include EncryptAttribute
  prepend ValueToString

  module LegacySecret
    extend ActiveSupport::Concern

    included do
      before_validation :infer_mode
      before_save   :sync_s3,        if: :legacy_secret?
      before_save   :wipe_value,     if: :legacy_secret?
      after_destroy :delete_from_s3, if: :legacy_secret?
    end

    def s3_path
      "heritages/#{heritage.name}/env/#{key}"
    end

    def sync_s3
      if legacy_secret?
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
      self.value = nil if legacy_secret?
    end

    def infer_mode
      self.mode = secret? ? "legacy_secret" : "plain" if self.mode.nil?
    end
  end

  include LegacySecret

  delegate :district, to: :heritage

  belongs_to :heritage

  validates :key, uniqueness: {scope: :heritage_id}, presence: true
  validates :value, presence: true, unless: :legacy_secret?

  encrypted_attribute :value, secret_key: ENV['ENCRYPTION_KEY']

  def key_presentation
    if transit?
      "__SECRET__" + key
    else
      key
    end
  end

  private

  def legacy_secret?
    mode == "legacy_secret"
  end

  def plain?
    mode == "plain"
  end

  def transit?
    mode == "transit"
  end
end
