module DirectConnect
  module Fixtures
    HOME_DIR = RUBY_PLATFORM =~ /mswin32/ ? ENV['HOMEPATH'] : ENV['HOME'] unless defined?(HOME_DIR)
    LOCAL_CREDENTIALS = File.join(HOME_DIR.to_s, '.killbill/direct_connect_fixtures.yml') unless defined?(LOCAL_CREDENTIALS)
    DEFAULT_CREDENTIALS = File.join(File.dirname(__FILE__), 'direct_connect_fixtures.yml') unless defined?(DEFAULT_CREDENTIALS)

    def fixtures(key)
      data = all_fixtures[key] || raise(StandardError, "No fixture data was found for '#{key}'")

      data.dup
    end

    private
    def credit_card(number = '4242424242424242', customer = generate_test_customer)
      defaults = {
          :number => number,
          :month => 9,
          :year => Time.now.year + 1,
          :first_name => customer.firstname,
          :last_name => customer.lastname,
          :verification_value => '123',
          :brand => 'visa'
      }

      ActiveMerchant::Billing::CreditCard.new(defaults)
    end

    def credit_card_with_track_data(number = '4242424242424242')
      defaults = {
          :track_data => '%B' + number + '^LONGSEN/L. ^15121200000000000000**123******?',
      }

      Billing::CreditCard.new(defaults)
    end

    def generate_test_customer
      defaults = {
          firstname: 'Jim',
          lastname:  'Smith',
          street1:   '1234 My Street',
          street2:   'Apt 1',
          company:   'Widgets Inc',
          city:      'Ottawa',
          state:     'ON',
          zip:       'K1C2N6',
          country:   'CA',
          dayphone:  '(555)555-5555',
          fax:       '(555)555-6666'
      }
      KillBill::DirectConnect::Customer.new(defaults)
    end

    def generate_unique_id
      SecureRandom.hex(16)
    end

    def all_fixtures
      @@fixtures ||= load_fixtures
    end

    def load_fixtures
      [DEFAULT_CREDENTIALS, LOCAL_CREDENTIALS].inject({}) do |credentials, file_name|
        if File.exist?(file_name)
          yaml_data = YAML.load(File.read(file_name))
          credentials.merge!(symbolize_keys(yaml_data))
        end
        credentials
      end
    end

    def symbolize_keys(hash)
      return unless hash.is_a?(Hash)

      hash.symbolize_keys!
      hash.each{|k,v| symbolize_keys(v)}
    end
  end
end
