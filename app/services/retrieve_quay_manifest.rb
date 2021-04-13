class RetrieveQuayManifest

    def process(user, password, heritage)
        image_name = heritage.image_name
        unless image_name.start_with?("quay.io/")
            raise ExceptionHandler::InternalServerError.new("Registry should be quay.io")
        end

        repo = image_name.sub('quay.io/', "")
        tag = heritage.tag

        uri = URI.parse("https://quay.io/v2/auth?service=quay.io&scope=repository:#{repo}:pull")

        request = Net::HTTP::Get.new(uri)
        request.basic_auth(user, password)

        req_options = {
            use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
            http.request(request)
        end

        if response.code != "200"
            return response
        end

        token = JSON.parse(response.body)["token"]

        uri = URI.parse("https://quay.io/v2/#{repo}/manifests/#{tag}")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Accept"] = "application/vnd.docker.distribution.manifest.v2+json"

        req_options = {
            use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
            http.request(request)
        end

        response
	end
  end
