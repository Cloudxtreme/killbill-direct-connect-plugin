module Killbill #:nodoc:
  module DirectConnect #:nodoc:
    class PrivatePaymentPlugin < ::Killbill::Plugin::ActiveMerchant::PrivatePaymentPlugin
      def initialize(session = {})
        super(:direct_connect,
              ::Killbill::DirectConnect::DirectConnectPaymentMethod,
              ::Killbill::DirectConnect::DirectConnectTransaction,
              ::Killbill::DirectConnect::DirectConnectResponse,
              session)
      end
    end
  end
end
