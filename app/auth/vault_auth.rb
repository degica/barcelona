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
      user = User.find_or_create_by(name: username)
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
    if !cap_probe.authorized?(non_shallow_path(request.path), request.method)
      raise ExceptionHandler::Forbidden.new("You are not authorized to do that action")
    end
  end

  def username
    client = Vault::Client.new(address: VaultAuth.vault_url)
    reply = client.auth.token vault_token
    reply.data.fetch(:meta, nil)&.fetch(:username, "vault-user#{vault_token.hash.to_s(16)}")
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

  # For heritages paths, bcn cli uses shallow paths e.g. "/v1/heritages/name" instead of "/v1/districts/district/heritages/name"
  # because when `bcn run -H heritage-name rails c` is executed, the cli does not know what district the heritage belongs to.
  # But this shallow path doesn't work well with vault auth because often we want to allow developers full access to a certain district.
  # For example, if we want to allow developers to access all heritages in a staging district, we want to declare below capability
  #   path "secret/Barcelona/degica/v1/districts/staging*" {
  #     capabilities = ["create", "update", "read", "delete", "list"]
  #   }
  # This method converts shallow heritage paths to non-shallow paths so the above capability definition works.
  def non_shallow_path(path)
    match = path.match(%r{^/v([0-9]+)(/heritages/([^/]*).*)})
    return path if match.nil?

    district_name = Heritage.find_by(name: match[3]).district.name
    return "/v#{match[1]}/districts/#{district_name}" + match[2]
  end
end
