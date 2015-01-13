module Killbill #:nodoc:
  module DirectConnect #:nodoc:
    class PaymentPlugin < ::Killbill::Plugin::Payment


      def start_plugin
        Killbill::DirectConnect.initialize! @logger, @conf_dir, @kb_apis

        super

        @logger.info 'Killbill::DirectConnect::PaymentPlugin started'
      end

      def stop_plugin
        @transactions_refreshes.cancel

        super

        @logger.info 'Killbill::DirectConnect::PaymentPlugin stopped'
      end

      # return DB connections to the Pool if required
      def after_request
        ActiveRecord::Base.connection.close
      end


      def initialize
      end

      def authorize_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def capture_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def purchase_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def void_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def credit_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def refund_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def get_payment_info(kb_account_id, kb_payment_id, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def search_payments(search_key, offset, limit, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def add_payment_method(kb_account_id, kb_payment_method_id, payment_method_props, set_default, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def delete_payment_method(kb_account_id, kb_payment_method_id, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def get_payment_method_detail(kb_account_id, kb_payment_method_id, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def set_default_payment_method(kb_account_id, kb_payment_method_id, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def get_payment_methods(kb_account_id, refresh_from_gateway, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def search_payment_methods(search_key, offset, limit, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def reset_payment_methods(kb_account_id, payment_methods, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def build_form_descriptor(kb_account_id, descriptor_fields, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def process_notification(notification, properties, context)
        raise OperationUnsupportedByGatewayError
      end
      
    end
  end
end
