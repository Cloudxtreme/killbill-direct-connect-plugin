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
        @identifier = 'direct_connect'
        @payment_transaction_model = Killbill::DirectConnect::DirectConnectTransaction
        @payment_method_model = Killbill::DirectConnect::DirectConnectPaymentMethod
        @payment_response_model = Killbill::DirectConnect::DirectConnectResponse
      end

      def authorize_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def capture_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        raise OperationUnsupportedByGatewayError
      end

      def purchase_payment(kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context)
        gateway_call_proc = Proc.new do |gateway, linked_transaction, payment_source, amount_in_cents, options|
          customer = build_customer(options)
          gateway.purchase(amount_in_cents, payment_source, customer, options[:order_id])
        end
        dispatch_to_gateways(:purchase, kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, gateway_call_proc)
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
        all_properties               = (payment_method_props.nil? || payment_method_props.properties.nil? ? [] : payment_method_props.properties) + properties
        options                      = combine_options(all_properties, kb_payment_method_id, set_default)
        gateway                      = KillBill::DirectConnect::Gateway.new(options)
        customer                     = build_customer(options)
        payment                      = build_payment_method(options, customer)
        customer_response            = gateway.add_customer(customer)
        customer.customerkey         = customer_response.params["customerkey"]
        card_response                = gateway.store_card(payment, customer)

        if card_response.success?
          payment_method = @payment_method_model.from_response(kb_account_id,
                                                              kb_payment_method_id,
                                                              context.tenant_id,
                                                              payment,
                                                              card_response,
                                                              options,
                                                              {},
                                                              @payment_method_model)

          payment_response = @payment_response_model.from_response('add_payment_method',
                                                                  kb_account_id,
                                                                  kb_payment_method_id,
                                                                  options[:order_id],
                                                                  :PURCHASE,
                                                                  @identifier,
                                                                  context.tenant_id,
                                                                  card_response,
                                                                  {},
                                                                  @payment_response_model)

          payment_method.save!
          payment_response.save!
          payment_method
        else
          raise card_response.message
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

      def dispatch_to_gateways(operation, kb_account_id, kb_payment_id, kb_payment_transaction_id, kb_payment_method_id, amount, currency, properties, context, gateway_call_proc, linked_transaction_proc=nil)
        kb_transaction          = get_kb_transaction(kb_payment_id, kb_payment_transaction_id, context.tenant_id)
        amount_in_cents         = amount.nil? ? nil : to_cents(amount, currency)
        options                 = combine_options(properties, kb_payment_method_id)
        options[:order_id]    ||= kb_transaction.external_key
        options[:currency]    ||= currency.to_s.upcase unless currency.nil?
        options[:description] ||= "Kill Bill #{operation.to_s} for #{kb_payment_transaction_id}"
        gateway                 = KillBill::DirectConnect::Gateway.new(options)
        payment_source          = get_payment_source(kb_payment_method_id, properties, options, context)

        # Sanity checks
        if [:authorize, :purchase, :credit].include?(operation)
          raise "Unable to retrieve payment source for operation=#{operation}, kb_payment_id=#{kb_payment_id}, kb_payment_transaction_id=#{kb_payment_transaction_id}, kb_payment_method_id=#{kb_payment_method_id}" if payment_source.nil?
        end

        # Retrieve the linked transaction (authorization to capture, purchase to refund, etc.)
        linked_transaction = nil
        unless linked_transaction_proc.nil?
          linked_transaction                     = linked_transaction_proc.call(amount_in_cents, options)
          options[:payment_processor_account_id] ||= linked_transaction.payment_processor_account_id
        end

        # Dispatch to the gateways. In most cases (non split settlements), we only dispatch to a single gateway account
        gw_responses                  = []
        responses                     = []
        transactions                  = []
        payment_processor_account_ids = options[:payment_processor_account_ids].nil? ? [options[:payment_processor_account_id] || :default] : options[:payment_processor_account_ids].split(',')

        payment_processor_account_ids.each do |payment_processor_account_id|
          # Perform the operation in the gateway
          gw_response           = gateway_call_proc.call(gateway, linked_transaction, payment_source, amount_in_cents, options)
          response, transaction = save_response_and_transaction(gw_response, operation, kb_account_id, context.tenant_id, payment_processor_account_id, kb_payment_id, kb_payment_transaction_id, operation.upcase, amount_in_cents, currency)

          gw_responses << gw_response
          responses << response
          transactions << transaction
        end

        # Merge data
        merge_transaction_info_plugins(payment_processor_account_ids, responses, transactions)
      end

      def properties_to_hash(properties, options = {})
        merged = {}
        (properties || []).each do |p|
          merged[p.key.to_sym] = p.value
        end
        merged.merge(options)
      end

      def hash_to_properties(options)
        merge_properties([], options)
      end

      def merge_properties(properties, options)
        merged = properties_to_hash(properties, options)

        properties = []
        merged.each do |k, v|
          p       = ::Killbill::Plugin::Model::PluginProperty.new
          p.key   = k
          p.value = v
          properties << p
        end
        properties
      end

      def combine_options(properties, kb_payment_method_id, set_default = nil)
        options                   = properties_to_hash(properties)
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

      def get_kb_transaction(kb_payment_id, kb_payment_transaction_id, kb_tenant_id)
        kb_payment     = @kb_apis.payment_api.get_payment(kb_payment_id, false, [], @kb_apis.create_context(kb_tenant_id))
        kb_transaction = kb_payment.transactions.find { |t| t.id == kb_payment_transaction_id }
        # This should never happen...
        raise ArgumentError.new("Unable to find Kill Bill transaction for id #{kb_payment_transaction_id}") if kb_transaction.nil?
        kb_transaction
      end

      def to_cents(amount, currency)
        # Use Money to compute the amount in cents, as it depends on the currency (1 cent of BTC is 1 Satoshi, not 0.01 BTC)
        ::Monetize.from_numeric(amount, currency).cents.to_i
      end

      def get_payment_source(kb_payment_method_id, properties, options, context)
        # Use ccNumber for the real number (if stored locally) or an in-house token (proxy tokenization). It is assumed the rest
        # of the card details are filled (expiration dates, etc.).
        cc_number   = find_value_from_properties(properties, 'ccNumber')
        # Use token for the token stored in an external vault. The token itself should be enough to process payments.
        cc_or_token = find_value_from_properties(properties, 'token') || find_value_from_properties(properties, 'cardId')

        if cc_number.blank? and cc_or_token.blank?
          # Lookup existing token
          pm = @payment_method_model.from_kb_payment_method_id(kb_payment_method_id, context.tenant_id)
          if pm.token.nil?
            # Real credit card
            cc_or_token = ::ActiveMerchant::Billing::CreditCard.new(
                :number             => pm.cc_number,
                :brand              => pm.cc_type,
                :month              => pm.cc_exp_month,
                :year               => pm.cc_exp_year,
                :verification_value => pm.cc_verification_value,
                :first_name         => pm.cc_first_name,
                :last_name          => pm.cc_last_name
            )
          else
            # Tokenized card
            cc_or_token = pm.token
          end
        elsif !cc_number.blank? and cc_or_token.blank?
          # Real credit card
          cc_or_token = ::ActiveMerchant::Billing::CreditCard.new(
              :number             => cc_number,
              :brand              => find_value_from_properties(properties, 'ccType'),
              :month              => find_value_from_properties(properties, 'ccExpirationMonth'),
              :year               => find_value_from_properties(properties, 'ccExpirationYear'),
              :verification_value => find_value_from_properties(properties, 'ccVerificationValue'),
              :first_name         => find_value_from_properties(properties, 'ccFirstName'),
              :last_name          => find_value_from_properties(properties, 'ccLastName')
          )
        else
          # Use specified token
        end

        options[:billing_address] ||= {
            :email    => find_value_from_properties(properties, 'email'),
            :address1 => find_value_from_properties(properties, 'address1'),
            :address2 => find_value_from_properties(properties, 'address2'),
            :city     => find_value_from_properties(properties, 'city'),
            :zip      => find_value_from_properties(properties, 'zip'),
            :state    => find_value_from_properties(properties, 'state'),
            :country  => find_value_from_properties(properties, 'country')
        }

        # To make various gateway implementations happy...
        options[:billing_address].each { |k, v| options[k] ||= v }

        cc_or_token
      end

      def find_value_from_properties(properties, key)
        return nil if key.nil?
        prop = (properties.find { |kv| kv.key.to_s == key.to_s })
        prop.nil? ? nil : prop.value
      end

      def save_response_and_transaction(gw_response, api_call, kb_account_id, kb_tenant_id, payment_processor_account_id, kb_payment_id=nil, kb_payment_transaction_id=nil, transaction_type=nil, amount_in_cents=0, currency=nil)
        @logger.warn "Unsuccessful #{api_call}: #{gw_response.message}" unless gw_response.success?

        response, transaction = @payment_response_model.create_response_and_transaction(@identifier,
                                                                                        @payment_transaction_model,
                                                                                        api_call,
                                                                                        kb_account_id,
                                                                                        kb_payment_id,
                                                                                        kb_payment_transaction_id,
                                                                                        transaction_type,
                                                                                        payment_processor_account_id,
                                                                                        kb_tenant_id,
                                                                                        gw_response,
                                                                                        amount_in_cents,
                                                                                        currency,
                                                                                        {},
                                                                                        @payment_response_model)

        @logger.debug { "Recorded transaction: #{transaction.inspect}" } unless transaction.nil?

        return response, transaction
      end

      def merge_transaction_info_plugins(payment_processor_account_ids, responses, transactions)
        result                             = Killbill::Plugin::Model::PaymentTransactionInfoPlugin.new
        result.amount                      = nil
        result.properties                  = []
        result.status                      = :PROCESSED
        # Nothing meaningful we can set here
        result.first_payment_reference_id  = nil
        result.second_payment_reference_id = nil

        responses.each_with_index do |response, idx|
          t_info_plugin = response.to_transaction_info_plugin(transactions[idx])
          if responses.size == 1
            # We're done
            return t_info_plugin
          end

          # Unique values
          [:kb_payment_id, :kb_transaction_payment_id, :transaction_type, :currency].each do |element|
            result_element        = result.send(element)
            t_info_plugin_element = t_info_plugin.send(element)
            if result_element.nil?
              result.send("#{element}=", t_info_plugin_element)
            elsif result_element != t_info_plugin_element
              raise "#{element.to_s} mismatch, #{result_element} != #{t_info_plugin_element}"
            end
          end

          # Arbitrary values
          [:created_date, :effective_date].each do |element|
            if result.send(element).nil?
              result.send("#{element}=", t_info_plugin.send(element))
            end
          end

          t_info_plugin.properties.each do |property|
            prop       = Killbill::Plugin::Model::PluginProperty.new
            prop.key   = "#{property.key}_#{payment_processor_account_ids[idx]}"
            prop.value = property.value
            result.properties << prop
          end

          if result.amount.nil?
            result.amount = t_info_plugin.amount
          elsif !t_info_plugin.nil?
            # TODO Adding decimals - are we losing precision?
            result.amount = result.amount + t_info_plugin.amount
          end

          # We set an error status if we have at least one error
          # TODO Does this work well with retries?
          if t_info_plugin.status == :ERROR
            result.status             = :ERROR

            # Return the first error
            result.gateway_error      = t_info_plugin.gateway_error if  result.gateway_error.nil?
            result.gateway_error_code = t_info_plugin.gateway_error_code if  result.gateway_error_code.nil?
          end
        end

        result
      end

    end
  end
end
