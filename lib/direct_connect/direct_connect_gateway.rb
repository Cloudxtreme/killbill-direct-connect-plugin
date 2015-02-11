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
          23 => :invalidAccountNumber,
          26 => :invalidPnRef,
          1015 => :noRecordsToProcess
      }

      def initialize(options={})
        requires!(options, :username, :password, :vendorid)
        @username = options[:username]
        @password = options[:password]
        @vendor = options[:vendorid]
        super
      end

      def purchase(money, payment, options={})
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_authentication(post, options)

        post[:transtype] = 'sale'
        post[:magdata] = options[:track_data]

        commit(:saleCreditCard, post)
      end

      def authorize(money, payment, options={})
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_authentication(post, options)

        post[:transtype] = 'Auth'
        post[:magdata] = options[:track_data]

        commit(:authCreditCard, post)
      end

      # could not implement remote tests for capture due to it not being enabled on our gateway
      def capture(money, authorization, options={})
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_customer_data(post, options)
        add_authentication(post, options)

        post[:transtype] = 'Capture'
        post[:pnref] = authorization

        commit(:saleCreditCard, post)
      end

      def refund(money, payment, authorization, options={})
        post = {}

        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_authentication(post, options)

        post[:transtype] = 'Return'
        post[:pnref] = authorization

        commit(:returnCreditCard, post)
      end

      def void(authorization, options={})
        post = {}

        add_authentication(post, options)

        post[:cardNum] = nil
        post[:cvnum] = nil
        post[:expdate] = nil
        post[:amount] = nil
        post[:invnum] = options[:order_id]
        post[:zip] = nil
        post[:street] = nil
        post[:nameOnCard] = nil
        post[:transType] = 'void'
        post[:extData] = nil
        post[:pnRef] = authorization
        post[:magData] = options[:magData]

        commit(:voidCreditCard, post)
      end

      def verify(credit_card, options={})
        ActiveMerchant::Billing::MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
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

      def add_customer(options)
        post = {}

        add_authentication(post, options)
        add_customer_data(post, options)

        post[:transtype] = 'add'
        commit(:addCustomer, post)
      end

      def update_customer(options)
        post = {}

        add_authentication(post, options)
        add_customer_data(post, options)

        post[:customerkey] = options[:customerkey]
        post[:transtype] = 'update'
        commit(:updateCustomer, post)
      end

      def delete_customer(options)
        post = {}

        add_authentication(post, options)
        add_customer_data(post, options)

        post[:customerkey] = options[:customerkey]
        post[:transtype] = 'delete'
        commit(:deleteCustomer, post)
      end

      def add_card(payment, options)
        post = {}

        add_authentication(post, options)
        add_payment(post, payment)
        add_credit_card_info(post, options)

        post[:transtype] = 'add'
        commit(:addCard, post)
      end

      def update_card(payment, options)
        post = {}

        add_authentication(post, options)
        add_payment(post, payment)
        add_credit_card_info(post, options)

        post[:transtype] = 'update'
        commit(:updateCard, post)
      end

      def delete_card(payment, options)
        post = {}

        add_authentication(post, options)
        add_payment(post, payment)
        add_credit_card_info(post, options)

        post[:transtype] = 'delete'
        commit(:deleteCard, post)
      end

      def store_card(payment, options)
        post = {}

        add_authentication(post, options)
        store_credit_card_info(post, options)
        add_address(post, payment, options)
        add_payment(post, payment)

        post[:tokenmode] = 'default'
        commit(:storeCard, post)
      end

      def process_stored_card(money, options)
        post = {}

        add_authentication(post, options)
        add_invoice(post, money, options)

        process_credit_card_info(post, options)

        post[:transtype] = 'sale'
        post[:tokenmode] = 'default'
        commit(:processCardSafeCard, post)
      end

      def process_stored_card_recurring(money, options)
        post = {}

        add_authentication(post, options)
        add_invoice(post, money, options)

        post[:ccinfokey] = options[:ccinfokey]
        post[:extdata] = nil
        commit(:processCardRecurring, post)
      end

      private

      def add_authentication(post, options)
        post[:username] = @username
        post[:password] = @password
        post[:vendor] = @vendor
      end

      def add_customer_data(post, options)
        # these do not match up well with options[:billing_address]
        post[:customerkey] = nil
        post[:customerid] = nil
        post[:customername] = options[:billing_address][:name]
        post[:firstname] = options[:firstname]
        post[:lastname] = options[:lastname]
        post[:title] = options[:title]
        post[:department] = options[:billing_address][:company]
        post[:street1] = options[:billing_address][:address1]
        post[:street2] = options[:billing_address][:address2]
        post[:street3] = options[:street3]
        post[:city] = options[:billing_address][:city]
        post[:stateid] = options[:billing_address][:state]
        post[:province] = options[:province]
        post[:zip] = options[:billing_address][:zip]
        post[:countryid] = options[:billing_address][:country]
        post[:email] = options[:email]
        post[:dayphone] = options[:billing_address][:phone]
        post[:nightphone] = options[:nightphone]
        post[:fax] = options[:billing_address][:fax]
        post[:mobile] = options[:mobile]
        post[:status] = options[:status]
        post[:extdata] = nil
      end

      def add_credit_card_info(post, options)
        post[:transtype] = options[:transtype]
        post[:customerkey] = options[:customerkey]
        post[:cardinfokey] = options[:ccinfokey]
        # direct connect uses different fields in different places
        post[:ccaccountnum] = post[:cardnum]
        post[:ccexpdate] = post[:expdate]
        post[:ccnameoncard] = options[:nameoncard]
        post[:ccstreet] = options[:street]
        post[:cczip] = options[:zip]
        post[:extdata] = nil
      end

      def store_credit_card_info(post, options)
        post[:tokenmode] = options[:tokenmode]
        post[:customerkey] = options[:customerkey]
        post[:extdata] = nil
      end

      def process_credit_card_info(post, options)
        post[:transtype] = options[:transtype]
        post[:cardtoken] = options[:cardtoken]
        post[:tokenmode] = options[:tokenmode]
        post[:pnref] = options[:pnref]
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

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:nameoncard] = address[:name]
          post[:street] = address[:address1]
          post[:zip] = address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:invNum] = options[:order_id]
      end

      def add_payment(post, payment)
        exp_date = payment.expiry_date.expiration.strftime('%02m%02y')

        post[:cardnum] = payment.number
        post[:expdate] = exp_date
        post[:cvnum] = payment.verification_value
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