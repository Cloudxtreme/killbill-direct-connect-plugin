module KillBill
  module DirectConnect

    mattr_reader :logger
    mattr_reader :conf_dir
    mattr_reader :config
    mattr_reader :kb_apis
    mattr_reader :initialized
    mattr_reader :test
    mattr_reader :merchant_api_key
    mattr_reader :client_id
    mattr_reader :client_secret
    mattr_reader :redirect_uri
    mattr_reader :app_redirect_uri
    mattr_reader :merchant_btc_address
    mattr_reader :transactions_refresh_interval
    mattr_reader :transactions_refresh_update_killbill
    mattr_reader :base_uri

    def self.initialize!(logger=Logger.new(STDOUT), conf_dir=File.expand_path('../../../', File.dirname(__FILE__)), kb_apis = nil)

    end
  end
end