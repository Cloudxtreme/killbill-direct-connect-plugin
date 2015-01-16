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
        1015 => :noRecordsToProcess,
        'Invalid_Argument' => :invalid_argument,
        'OK' => :success
      }

      def initialize(options={})
        requires!(options, :username, :password)
        @username = options[:username]
        @password = options[:password]
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
        post[:pnref] =  authorization

        commit(:saleCreditCard, post)
      end

      def refund(money, payment, authorization, options={})
        post = {}
        
        add_required_nil_values(post)
        add_invoice(post, money, options)
        add_authentication(post, options)
        
        post[:transtype] = 'Return'
        post[:pnref] =  authorization

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
        post[:pnRef] =  authorization
        post[:magData] = options[:magData]

        commit(:voidCreditCard, post)
      end

      def verify(credit_card, options={})
        ActiveMerchant::Billing::MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # Recurring

      ##
      # Adds a recurring payment contract to the specified customer
      #
      # notes from https://www.evernote.com/shard/s341/sh/3f2ae114-ce86-4cd5-833e-741b8e475317/079e709598f43cf1
      def add_contract(payment_token, options)
        post = {}
        add_contract_data(post, options[:contract])
        add_payment_token(post, payment_token)
        add_authentication(post, options)
        add_customer_data(post, options[:customer])

        post[:transtype] = 'Add'
        commit(:add_contract, post)
      end

      def update_contract(options)
        post = {}
        commit(:update_contract, post)
      end

      def delete_contract(options)
        post = {}
        commit(:delete_contract, post)
      end

      def add_contract_data(post, contract_data)
        post[:contractkey] = contract_data[:contract_key]
        post[:contractid] = contract_data[:contract_id]
        post[:contractname] = contract_data[:name]

        amt = contract_data[:amount]
        post[:billamt] = amount(amt[:bill])
        post[:taxamt] = amount(amt[:tax])
        post[:totalamt] = amount(amt[:total])

        post[:startdate] = contract_data[:start_date]
        post[:enddate] = contract_data[:end_date]
        post[:nextbilldt] = contract_data[:next_bill_date]

        post[:billingperiod] = contract_data[:period].to_s
        post[:billinginterval] = contract_data[:interval]

        post[:maxfailures] = nil
        post[:failureinterval] = nil
        post[:emailcustomer] = nil
        post[:emailmerchant] = nil
        post[:emailcustomerfailure] = nil
        post[:emailmerchantfailure] = nil

        post[:status] = 'ACTIVE'
        post[:extdata] = nil
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

      private

      def add_authentication(post, options)
        post[:username] = @username
        post[:password] = @password
        post[:vendor] = options[:vendor] unless options[:vendor].nil?
      end

      def add_customer_data(post, customer)
        post[:customerkey] = customer[:key]
        post[:customerid] = customer[:id]
        post[:customername] = customer[:name]
        post[:firstname] = nil
        post[:lastname] = nil
        post[:title] = nil
        post[:department] = nil
        post[:street1] = nil
        post[:street2] = nil
        post[:street3] = nil
        post[:city] = nil
        post[:stateid] = nil
        post[:province] = nil
        post[:zip] = nil
        post[:countryid] = nil
        post[:dayphone] = nil
        post[:nightphone] = nil
        post[:fax] = nil
        post[:email] = nil
        post[:mobile] = nil
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
          post[:pnref] =  nil
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

      def add_payment_token(post, payment_token)
        post[:paymenttype] = 'CC'
        post[:paymentinfokey] = payment_token.token
      end

      def parse(action, body)
        doc = Nokogiri::XML(body)
        manage_contract = actionToService(action) == :manage_contract
        doc.remove_namespaces!
        response = {action: action}
        root_path = "//Response"
        result_path = "//Response/Result"

        if manage_contract then
          result_path = "//RecurringResult"
          root_path = result_path
        end

        # special parsing
        if manage_contract then
          if code = doc.at_xpath('//RecurringResult/Code') then
            response[:result] = code.content
          else
            response[:result] = 0
          end
        else
          result = doc.at_xpath(result_path).content.to_i
        end

        if el = doc.at_xpath("//Response/PNRef")
          response[:pnref] = el.content.to_i
        end

        # parse everything else
        doc.at_xpath(root_path).element_children.each do |node|
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
        case response[:action]
        when :add_contract, :update_contract, :delete_contract
          DIRECT_CONNECT_CODES[response[:code]] == :success
        else
          DIRECT_CONNECT_CODES[response[:result]] == :success
        end
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
        when :add_contract, :update_contract, :delete_contract
          :manage_contract
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
        when :processCardRecurring
          "paygate/ws/recurring.asmx/ProcessCreditCard"
        when :manage_contract
          "paygate/ws/recurring.asmx/ManageContract"
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