module Killbill #:nodoc:
  module DirectConnect #:nodoc:
    class DirectConnectTransaction < ::Killbill::Plugin::ActiveMerchant::ActiveRecord::Transaction

      self.table_name = 'direct_connect_transactions'

      belongs_to :direct_connect_response

    end
  end
end
