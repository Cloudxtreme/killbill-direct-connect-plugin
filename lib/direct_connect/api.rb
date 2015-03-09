module Killbill #:nodoc:
  module DirectConnect #:nodoc:
    class PaymentPlugin < ::Killbill::Plugin::Payment

      def start_plugin
        initialize

        super

        @logger.info 'Killbill::DirectConnect::PaymentPlugin started'
      end

      def stop_plugin
        # @transactions_refreshes.cancel

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
        options              = combine_options(payment_method_props, properties, kb_payment_method_id, set_default)
        gateway              = KillBill::DirectConnect::Gateway.new(options)
        customer             = build_customer(options)
        payment              = build_payment_method(options, customer)
        customer_response    = gateway.add_customer(customer)
        customer.customerkey = customer_response.params["customerkey"]
        card_response        = gateway.store_card(payment, customer)

        if card_response.success?
          payment_method_model = Killbill::DirectConnect::DirectConnectPaymentMethod
          payment_method = payment_method_model.from_response(kb_account_id,
                                                              kb_payment_method_id,
                                                              context.tenant_id,
                                                              payment,
                                                              card_response,
                                                              options,
                                                              {},
                                                              payment_method_model)

          payment_response_model = Killbill::DirectConnect::DirectConnectResponse
          payment_response = payment_response_model.from_response('add_payment_method',
                                                                  kb_account_id,
                                                                  kb_payment_method_id,
                                                                  options[:order_id],
                                                                  :PURCHASE,
                                                                  'direct_connect',
                                                                  context.tenant_id,
                                                                  card_response,
                                                                  {},
                                                                  payment_response_model)

          payment_method.save!
          payment_response.save!
          payment_method
        else
          raise response.message
        end
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

      private

      def properties_to_hash(properties, options = {})
        merged = {}
        (properties || []).each do |p|
          merged[p.key.to_sym] = p.value
        end
        merged.merge(options)
      end

      def combine_options(payment_method_props, properties, kb_payment_method_id, set_default)
        all_properties            = (payment_method_props.nil? || payment_method_props.properties.nil? ? [] : payment_method_props.properties) + properties
        options                   = properties_to_hash(all_properties)
        options[:order_id]      ||= kb_payment_method_id
        options[:set_default]   ||= set_default
        options[:billing_address] = build_billing_address(options)
        options
      end

      def build_customer(options)
        customer_attributes = {
            firstname:  options[:ccFirstName],
            lastname:   options[:ccLastName],
            title:      options[:title],
            department: options[:department],
            street1:    options[:address1],
            street2:    options[:address2],
            street3:    options[:address3],
            city:       options[:city],
            state:      options[:state],
            province:   options[:province],
            zip:        options[:zip],
            country:    options[:country],
            email:      options[:email],
            mobile:     options[:mobile],
            dayphone:   options[:dayphone],
            nightphone: options[:nightphone],
            fax:        options[:fax],
            customerid: options[:customerid],
            status:     options[:status]
        }
        KillBill::DirectConnect::Customer.new(customer_attributes)
      end

      def build_payment_method(options, customer)
        payment_attributes = {
            :number => options[:ccNumber],
            :month => options[:ccExpirationMonth],
            :year => options[:ccExpirationYear],
            :first_name => customer.firstname,
            :last_name => customer.lastname,
            :verification_value => options[:ccVerificationValue],
            :brand => options[:ccType]
        }
        ActiveMerchant::Billing::CreditCard.new(payment_attributes)
      end

      def build_billing_address(options)
        billing_address = {}
        billing_address[:address1] = options[:address1]
        billing_address[:address2] = options[:address2]
        billing_address[:city] = options[:city]
        billing_address[:state] = options[:state]
        billing_address[:zip] = options[:zip]
        billing_address[:country] = options[:country]
        billing_address
      end

    end
  end
end
