require 'nokogiri'
require 'active_utils/common/posts_data'

module KillBill #:nodoc:
  module DirectConnect #:nodoc:
    class Gateway < ActiveMerchant::Billing::Gateway
      include ActiveMerchant::PostsData

      self.test_url = 'https://gateway.1directconnect.com/'
      self.live_url = 'https://gateway.1directconnect.com/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.directconnectps.com/'
      self.display_name = 'Direct Connect'

      DIRECT_CONNECT_CODES = {
          0 => :success,
          12 => :verification_rejected,
          23 => :invalid_account_number,
          26 => :invalid_pnref,
          113 => :sales_cap_exceeded,
          1000 => :invalid_card_token,
          1001 => :invalid_customer_key,
          1015 => :no_records_to_process
      }

      def initialize(options={})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
        @vendor = options[:vendorid]
        super
      end

      def get_direct_connect_code(response)
        KillBill::DirectConnect::Gateway::DIRECT_CONNECT_CODES[response.params['result']]
      end

      def purchase(money, credit_card, customer, order_id)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_payment(post, credit_card)
        add_address(post, credit_card, customer)
        add_authentication(post)

        post[:transtype] = 'sale'

        commit(:sale_credit_card, post)
      end

      def authorize(money, credit_card, customer, order_id)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_payment(post, credit_card)
        add_address(post, credit_card, customer)
        add_authentication(post)

        post[:transtype] = 'Auth'

        commit(:auth_credit_card, post)
      end

      # could not implement remote tests for capture due to it not being enabled on our gateway
      def capture(money, authorization, order_id, customer)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_customer_data(post, customer)
        add_authentication(post)

        post[:transtype] = 'Capture'
        post[:pnref] = authorization

        commit(:sale_credit_card, post)
      end

      def refund(money, authorization, order_id)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_authentication(post)

        post[:transtype] = 'Return'
        post[:pnref] = authorization

        commit(:return_credit_card, post)
      end

      def void(authorization, order_id)
        post = {}

        add_authentication(post)
        add_required_nil_values(post)

        post[:invnum] = order_id
        post[:transtype] = 'void'
        post[:pnref] = authorization

        commit(:void_credit_card, post)
      end

      def verify(credit_card, customer, order_id)
        ActiveMerchant::Billing::MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, customer, order_id) }
          r.process(:ignore_result) { void(r.authorization, order_id) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
            .gsub(%r((username=)\w+), '\1[FILTERED]')
            .gsub(%r((password=)\w+), '\1[FILTERED]')
            .gsub(%r((cardnum=)\d+), '\1[FILTERED]')
            .gsub(%r((cvnum=)\d+), '\1[FILTERED]')
      end

      def add_customer(customer)
        post = {}

        add_authentication(post)
        add_customer_data(post, customer)

        post[:transtype] = 'add'

        commit(:add_customer, post)
      end

      def update_customer(customer)
        post = {}

        add_authentication(post)
        add_customer_data(post, customer)

        post[:transtype] = 'update'

        commit(:update_customer, post)
      end

      def delete_customer(customer)
        post = {}

        add_authentication(post)
        add_customer_data(post, customer)

        post[:transtype] = 'delete'

        commit(:delete_customer, post)
      end

      def add_card(credit_card, customer)
        post = {}

        add_authentication(post)
        add_credit_card_info(post, customer, credit_card, nil)

        post[:transtype] = 'add'

        commit(:add_card, post)
      end

      def update_card(credit_card, customer, card_info_key)
        post = {}

        add_authentication(post)
        add_credit_card_info(post, customer, credit_card, card_info_key)

        post[:transtype] = 'update'

        commit(:update_card, post)
      end

      def delete_card(credit_card, customer, card_info_key)
        post = {}

        add_authentication(post)
        add_credit_card_info(post, customer, credit_card, card_info_key)

        post[:transtype] = 'delete'

        commit(:delete_card, post)
      end

      def store_card(credit_card, customer)
        post = {}

        add_authentication(post)
        add_store_credit_card_info(post, customer)
        add_address(post, credit_card, customer)
        add_payment(post, credit_card)

        post[:tokenmode] = 'default'

        commit(:store_card_safe_card, post)
      end

      def process_stored_card(money, order_id, card_token)
        post = {}

        add_authentication(post)
        add_invoice(post, money, order_id)
        process_credit_card_info(post, card_token)

        post[:transtype] = 'sale'

        commit(:process_card_safe_card, post)
      end

      def process_stored_card_recurring(money, order_id, card_info_key)
        post = {}

        add_authentication(post)
        add_invoice(post, money, order_id)

        post[:ccinfokey] = card_info_key
        post[:extdata] = nil

        commit(:process_card_recurring, post)
      end

      private

      def add_authentication(post)
        post[:username] = @username
        post[:password] = @password
        post[:vendor] = @vendor
      end

      def add_customer_data(post, customer)
        post[:customerkey] = customer.customerkey
        post[:customerid] = customer.customerid
        post[:customername] = customer.customername
        post[:firstname] = customer.firstname
        post[:lastname] = customer.lastname
        post[:title] = customer.title
        post[:department] = customer.address.department
        post[:street1] = customer.address.street1
        post[:street2] = customer.address.street2
        post[:street3] = customer.address.street3
        post[:city] = customer.address.city
        post[:stateid] = customer.address.state
        post[:province] = customer.address.province
        post[:zip] = customer.address.zip
        post[:countryid] = customer.address.country
        post[:email] = customer.email
        post[:dayphone] = customer.dayphone
        post[:nightphone] = customer.nightphone
        post[:fax] = customer.fax
        post[:mobile] = customer.mobile
        post[:status] = customer.status
        post[:extdata] = nil
      end

      def add_credit_card_info(post, customer, credit_card, card_info_key)
        post[:customerkey] = customer.customerkey
        post[:cardinfokey] = card_info_key
        post[:ccaccountnum] = credit_card.number
        post[:ccexpdate] = credit_card.expiry_date.expiration.strftime('%02m%02y')
        post[:ccnameoncard] = credit_card.name
        post[:ccstreet] = customer.address.street1
        post[:cczip] = customer.address.zip
        post[:extdata] = nil
      end

      def add_store_credit_card_info(post, customer)
        post[:customerkey] = customer.customerkey
        post[:extdata] = nil
      end

      def process_credit_card_info(post, card_token)
        post[:cardtoken] = card_token
        post[:tokenmode] = 'default'
        post[:pnref] = nil
        post[:extdata] = nil
      end

      def add_required_nil_values(post)
        post[:amount] = nil
        post[:invNum] = nil
        post[:cardnum] = nil
        post[:expdate] = nil
        post[:cvnum] = nil
        post[:nameoncard] = nil
        post[:street] = nil
        post[:zip] = nil
        post[:extdata] = nil
        post[:magdata] = nil
        post[:pnref] = nil
      end

      def add_address(post, credit_card, customer)
          post[:nameoncard] = credit_card.name
          post[:street] = customer.address.street1
          post[:zip] = customer.address.zip
      end

      def add_invoice(post, money, order_id)
        post[:amount] = amount(money)
        post[:invnum] = order_id
      end

      def add_payment(post, credit_card)
        exp_date = credit_card.expiry_date.expiration.strftime('%02m%02y')

        post[:cardnum] = credit_card.number
        post[:expdate] = exp_date
        post[:cvnum] = credit_card.verification_value
      end

      def parse(action, body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!
        response = {action: action}

        service = action_to_service(action)

        # special parsing
        case service
          when :manage_customer, :manage_credit_card_info, :process_card_recurring
            response[:result] = doc.at_xpath("//RecurringResult/code").content.to_s == 'OK' ? 0 : nil
            result_to_parse = doc.at_xpath('//RecurringResult')
          else
            response[:result] = doc.at_xpath("//Response/Result").content.to_i

            if service == :store_card_safe_card && doc.at_xpath("//Response/ExtData") != nil
              token_doc = Nokogiri::XML(doc.at_xpath("//Response/ExtData").content.to_s)
              response[:cardtoken] = (token_doc.at_xpath("//CardSafeToken").nil?) ? nil : token_doc.at_xpath("//CardSafeToken").content.to_s
            end

            if el = doc.at_xpath("//Response/PNRef")
              response[:pnref] = el.content.to_i
            end

            result_to_parse = doc.at_xpath('//Response')
        end

        # parse everything else
        result_to_parse.element_children.each do |node|
          node_sym = node.name.downcase.to_sym
          response[node_sym] ||= normalize(node.content)
        end

        response
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        service = action_to_service(action)
        url = "#{url}#{service_url(service)}"
        begin
          data = post_data(action, parameters)
          response = parse(action, ssl_post(url, data))
        rescue ActiveMerchant::ResponseError => e
          puts e.response.body
        end

        ActiveMerchant::Billing::Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            test: test?
        )
      end

      def success_from(response)
        DIRECT_CONNECT_CODES[response[:result]] == :success
      end

      def message_from(response)
        case response[:respmsg]
          when 'Token generated successfully', 'Approved'
            'Successful transaction'
          else
            response[:respmsg]
        end
      end

      def authorization_from(response)
        response[:pnref] || response[:cardtoken]
      end

      def post_data(action, parameters = {})
        return nil unless parameters

        parameters.map do |k, v|
          "#{k}=#{CGI.escape(v.to_s)}"
        end.compact.join('&')
      end

      def action_to_service(action)
        case action
          when :auth_credit_card, :sale_credit_card, :return_credit_card, :void_credit_card
            :process_credit_card
          when :sale_check, :auth_check, :return_check, :void_check
            :process_check
          when :add_customer, :update_customer, :delete_customer
            :manage_customer
          when :add_card, :update_card, :delete_card
            :manage_credit_card_info
          else
            action
        end
      end

      def service_url(service)
        case service
          when :process_credit_card
            "ws/transact.asmx/ProcessCreditCard"
          when :process_check
            "ws/transact.asmx/ProcessCheck"
          when :store_card_safe_card
            "ws/cardsafe.asmx/StoreCard"
          when :process_card_safe_card
            "ws/cardsafe.asmx/ProcessCreditCard"
          when :process_card_recurring
            "paygate/ws/recurring.asmx/ProcessCreditCard"
          when :manage_customer
            "/paygate/ws/recurring.asmx/ManageCustomer"
          when :manage_credit_card_info
            "/paygate/ws/recurring.asmx/ManageCreditCardInfo"
        end
      end

      def amount(money)
        return nil if money.nil?
        cents = money

        if money.is_a?(String)
          raise ArgumentError, 'money amount must be a positive Integer in cents.'
        end

        sprintf("%.2f", cents.to_f / 100)
      end
    end
  end
end