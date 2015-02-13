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
          12 => :verificationRejected,
          23 => :invalidAccountNumber,
          26 => :invalidPnRef,
          1015 => :noRecordsToProcess
      }

      def initialize(options={})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
        @vendor = options[:vendorid]
        super
      end

      def purchase(money, credit_card, customer, order_id)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_payment(post, credit_card)
        add_address(post, credit_card, customer)
        add_authentication(post)

        post[:transtype] = 'sale'

        commit(:saleCreditCard, post)
      end

      def authorize(money, credit_card, customer, order_id)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_payment(post, credit_card)
        add_address(post, credit_card, customer)
        add_authentication(post)

        post[:transtype] = 'Auth'

        commit(:authCreditCard, post)
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

        commit(:saleCreditCard, post)
      end

      def refund(money, authorization, order_id)
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, order_id)
        add_authentication(post)

        post[:transtype] = 'Return'
        post[:pnref] = authorization

        commit(:returnCreditCard, post)
      end

      def void(authorization, order_id)
        post = {}

        add_authentication(post)
        add_required_nil_values(post)

        post[:invnum] = order_id
        post[:transtype] = 'void'
        post[:pnref] = authorization

        commit(:voidCreditCard, post)
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
        commit(:addCustomer, post)
      end

      def update_customer(customer)
        post = {}

        add_authentication(post)
        add_customer_data(post, customer)

        post[:transtype] = 'update'
        commit(:updateCustomer, post)
      end

      def delete_customer(customer)
        post = {}

        add_authentication(post)
        add_customer_data(post, customer)

        post[:transtype] = 'delete'
        commit(:deleteCustomer, post)
      end

      def add_card(credit_card, customer)
        post = {}

        add_authentication(post)
        add_credit_card_info(post, customer, credit_card, nil)

        post[:transtype] = 'add'
        commit(:addCard, post)
      end

      def update_card(credit_card, customer, card_info_key)
        post = {}

        add_authentication(post)
        add_credit_card_info(post, customer, credit_card, card_info_key)

        post[:transtype] = 'update'
        commit(:updateCard, post)
      end

      def delete_card(credit_card, customer, card_info_key)
        post = {}

        add_authentication(post)
        add_credit_card_info(post, customer, credit_card, card_info_key)

        post[:transtype] = 'delete'
        commit(:deleteCard, post)
      end

      def store_card(credit_card, customer)
        post = {}

        add_authentication(post)
        store_credit_card_info(post, customer)
        add_address(post, credit_card, customer)
        add_payment(post, credit_card)

        post[:tokenmode] = 'default'
        commit(:storeCard, post)
      end

      def process_stored_card(money, order_id, card_token)
        post = {}

        add_authentication(post)
        add_invoice(post, money, order_id)
        process_credit_card_info(post, card_token)

        post[:transtype] = 'sale'
        commit(:processCardSafeCard, post)
      end

      def process_stored_card_recurring(money, order_id, card_info_key)
        post = {}

        add_authentication(post)
        add_invoice(post, money, order_id)

        post[:ccinfokey] = card_info_key
        post[:extdata] = nil
        commit(:processCardRecurring, post)
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

      def store_credit_card_info(post, customer)
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
        post[:invNum] = order_id
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

        service = actionToService(action)

        # special parsing
        case service
          when :manageCustomer, :manageCreditCardInfo, :processCardRecurring
            response[:result] = doc.at_xpath("//RecurringResult/code").content.to_s == 'OK' ? 0 : nil
            result_to_parse = doc.at_xpath('//RecurringResult')
          else
            response[:result] = doc.at_xpath("//Response/Result").content.to_i

            if service == :storeCardSafeCard && doc.at_xpath("//Response/ExtData") != nil
              token_doc = Nokogiri::XML(doc.at_xpath("//Response/ExtData").content.to_s)
              response[:cardtoken] = token_doc.at_xpath("//CardSafeToken").content.to_s
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
        service = actionToService(action)
        url = "#{url}#{serviceUrl(service)}"
        begin
          data = post_data(action, parameters)
          response = parse(action, ssl_post(url, data))
        rescue ActiveMerchant::ResponseError => e
          puts e.response.body
        end

        p '            -=-+-=-   ' + action.to_s + ' post   -=-+-=-            '
        p data
        p '            -=-+-=-   ' + action.to_s + ' resp   -=-+-=-            '
        p response

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
        response[:respmsg]
      end

      def authorization_from(response)
        response[:pnref]
      end

      def post_data(action, parameters = {})
        return nil unless parameters

        parameters.map do |k, v|
          "#{k}=#{CGI.escape(v.to_s)}"
        end.compact.join('&')
      end

      def actionToService(action)
        case action
          when :authCreditCard, :saleCreditCard, :returnCreditCard, :voidCreditCard
            :processCreditCard
          when :saleCheck, :authCheck, :returnCheck, :voidCheck
            :processCheck
          when :addCustomer, :updateCustomer, :deleteCustomer
            :manageCustomer
          when :addCard, :updateCard, :deleteCard
            :manageCreditCardInfo
          when :storeCard, :processStoredCard
            :storeCardSafeCard
          else
            action
        end
      end

      def serviceUrl(service)
        case service
          when :processCreditCard
            "ws/transact.asmx/ProcessCreditCard"
          when :processCheck
            "ws/transact.asmx/ProcessCheck"
          when :storeCardSafeCard
            "ws/cardsafe.asmx/StoreCard"
          when :processCardSafeCard
            "ws/cardsafe.asmx/ProcessCreditCard"
          when :processCardRecurring
            "paygate/ws/recurring.asmx/ProcessCreditCard"
          when :manageCustomer
            "/paygate/ws/recurring.asmx/ManageCustomer"
          when :manageCreditCardInfo
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