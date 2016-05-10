class UseDegicaReverseProxy < ActiveRecord::Migration
  def change
    Service.
      where(reverse_proxy_image: "k2nr/reverse-proxy:latest").
      update_all(reverse_proxy_image: Service::DEFAULT_REVERSE_PROXY)
  end
end
