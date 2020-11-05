class VaultAuth < Auth
  def self.vault_url
    ENV['VAULT_URL']
  end

  def self.enabled?
    vault_url.present?
  end

  def login
    authenticate
  end

  def authenticate
    @current_user = User.find_by_token(vault_token)

    if @current_user.nil?
      user = User.new(name: "vault-user-#{vault_token.hash.to_s(16)}")
      user.auth = 'vault'
      user.token = vault_token
      user.roles = []
      user.save!
      @current_user = user
    end

    # assign the real token for use
    @current_user.token = vault_token if @current_user
    @current_user
  end

  # Ignore resource based authorization
  def authorize_resource(*args)
  end

  def authorize_action
    if !cap_probe.authorized?(request.path, request.method)
      raise ExceptionHandler::Forbidden.new("You are not authorized to do that action")
    end
  end

  private

  def vault_uri
    URI(VaultAuth.vault_url)
  end

  def vault_path_prefix
    ENV['VAULT_PATH_PREFIX']
  end

  def vault_token
    request.headers['HTTP_X_VAULT_TOKEN']
  end

  def cap_probe
    @cap_probe ||= Vault::CapProbe.new(vault_uri, vault_token, vault_path_prefix)
  end
end
