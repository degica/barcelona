module Vault
  class CapProbe
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
      case method
      when "POST"
        capabilities.include? "create"
      when "PATCH", "PUT"
        capabilities.include? "update"
      when "GET"
        capabilities.include? "read"
      when "DELETE"
        capabilities.include? "delete"
      else
        raise ExceptionHandler::Unauthorized.new("HTTP method not supported")
      end
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
