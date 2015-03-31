module ShopProductSink
  module Webhooks
    class ConfigurationError < StandardError; end
    extend ActiveSupport::Concern

    included do
      skip_before_filter :verify_authenticity_token
      before_filter :verify_webhook
    end

    def verify_webhook
      return if valid_webhook?
      head :unauthorized
    end

    def shop_id
      raise ConfigurationError.new("Unable to determine shop_id. Mixed-in object needs to implement this method")
    end

    def application_secret
      raise ConfigurationError.new("Unable to determine application secret. Mixed-in object needs to implement this method")
    end

    def valid_webhook?
      return true unless provided_hmac
      request.body.rewind
      calculated_hmac = hmac(request.body.read)
      calculated_hmac == provided_hmac
    end

    def no_signing_details?
      provided_hmac.nil?
    end

    def affected_resource
      topic.first.singularize
    end

    def event
      topic.last
    end

    def resource_id
      header_name = "X-Shopify-#{affected_resource.capitalize}-Id"
      request.headers[header_name]
    end

    def shopify_shop_domain
      request.headers["X-Shopify-Shop-Domain"]
    end

    def create?
      event == 'create'
    end

    def update?
      event == 'update'
    end

    def delete?
      event == 'delete'
    end

    private
    def digest
      OpenSSL::Digest.new('sha256')
    end

    def hmac(message)
      hmac = OpenSSL::HMAC.digest(digest, application_secret, message)
      Base64.strict_encode64(hmac)
    end

    def provided_hmac
      @provided_hmac ||= request.headers['X-Shopify-Hmac-SHA256']
    end

    def topic
      @topic ||= request.headers['X-Shopify-Topic'].split('/')
    end
  end
end
