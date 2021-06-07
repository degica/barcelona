module Vault
  class CapProbe
    # Maps HTTP methods to vault actions
    METHOD_MAP = {
      'POST' => 'create',
      'PATCH' => 'update',
      'PUT' => 'update',
      'GET' => 'read',
      'DELETE' => 'delete'
    }.freeze

    def initialize(vault_uri, vault_token, vault_path_prefix)
      @vault_uri = vault_uri
      @vault_token = vault_token
      @vault_path_prefix = vault_path_prefix
    end

    def prefix
      return '/' + @vault_path_prefix if @vault_path_prefix.present?

      ''
    end

    def authorized?(path, method)
      capabilities = retrieve_capabilites(path)
      return true if capabilities.include? 'root'

      vault_method = METHOD_MAP[method]
      raise ExceptionHandler::Unauthorized.new("HTTP method not supported") if vault_method.nil?

      capabilities.include? vault_method
    end

    def retrieve_capabilites(path)
      vault_path = "secret/Barcelona#{prefix}#{path}"

      req = Net::HTTP::Post.new("/v1/sys/capabilities-self")
      req.body = {paths: [vault_path]}.to_json

      req['X-Vault-Token'] = @vault_token
      http = Net::HTTP.new(@vault_uri.host, @vault_uri.port)
      http.use_ssl = true if @vault_uri.scheme == 'https'
      res = http.request(req)

      if res.code.to_i > 299
        Rails.logger.error "ERROR: Vault returned code #{res.code} and #{res.body.inspect}"
        raise ExceptionHandler::Forbidden.new("Your Vault token does not have a permission for #{req.path}")
      end

      JSON.load(res.body)["capabilities"]
    end
  end
end
