module Killbill
  module DirectConnect

    mattr_reader :logger
    mattr_reader :conf_dir
    mattr_reader :config
    mattr_reader :kb_apis
    mattr_reader :initialized
    mattr_reader :test
    mattr_reader :merchant_username
    mattr_reader :merchant_password
    mattr_reader :client_id
    mattr_reader :client_secret
    mattr_reader :redirect_uri
    mattr_reader :app_redirect_uri
    mattr_reader :merchant_btc_address
    mattr_reader :transactions_refresh_interval
    mattr_reader :transactions_refresh_update_killbill
    mattr_reader :base_uri

    def self.initialize!(logger=Logger.new(STDOUT), config_key_name="", conf_dir=File.expand_path('../../../', File.dirname(__FILE__)), kb_apis = nil)
      @@logger = logger
      @@kb_apis = kb_apis
      @@conf_dir = conf_dir
      @@config_key_name = config_key_name

      config_file = "#{conf_dir}/direct_connect.yml"
      @@config = Killbill::Plugin::ActiveMerchant::Properties.new(config_file)
      @@config.parse!
      @@test = @@config[:direct_connect][:test]

      @@merchant_username = @@config[:direct_connect][:username]
      @@merchant_password = @@config[:direct_connect][:password]

      @@base_uri = @@config[:direct_connect][:base_uri] || 'https://gateway.1directconnect.com/'

      @@logger.log_level = Logger::DEBUG if (@@config[:logger] || {})[:debug]

      if defined?(JRUBY_VERSION)
        # See https://github.com/jruby/activerecord-jdbc-adapter/issues/302
        require 'jdbc/mysql'
        Jdbc::MySQL.load_driver(:require) if Jdbc::MySQL.respond_to?(:load_driver)
      end

      ActiveRecord::Base.establish_connection(@@config[:database])
      ActiveRecord::Base.logger = @@logger

      # Make sure OpenSSL is correctly loaded
      javax.crypto.spec.IvParameterSpec.new(java.lang.String.new("dummy test").getBytes())

      # See https://github.com/reidmorrison/symmetric-encryption
      
      # ugggh this is going to suck
      # SymmetricEncryption.load!("#{conf_dir}/symmetric-encryption.yml", @@test ? 'test' : 'production')

      @@initialized = true
    end
  end
end