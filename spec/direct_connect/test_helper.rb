#!/usr/bin/env ruby
$:.unshift File.expand_path('../../lib', __FILE__)
$:.unshift File.dirname(__FILE__)

require 'direct_connect'

begin
  #require 'rubygems'
  #require 'bundler'
  #Bundler.setup
rescue LoadError => e
  puts "Error loading bundler (#{e.message}): \"gem install bundler\" for bundler support."
end

require 'minitest'
require 'mocha/setup'
require 'yaml'
require 'json'
require 'active_merchant'
require 'comm_stub'

require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/numeric/time'

begin
  require 'active_support/core_ext/time/acts_like'
rescue LoadError
end

module DirectConnect
  module Assertions
    AssertionClass = RUBY_VERSION > '1.9' ? MiniTest::Assertion : Test::Unit::AssertionFailedError

    def build_message(head, template=nil, *arguments) #:nodoc:
      template &&= template.chomp
      template.gsub(/\G((?:[^\\]|\\.)*?)(\\)?\?/) { $1 + ($2 ? "?" : mu_pp(arguments.shift)) }
    end

    def assert_field(field, value)
      clean_backtrace do
        assert_equal value, @helper.fields[field]
      end
    end

    # Allows testing of negative assertions:
    #
    #   # Instead of
    #   assert !something_that_is_false
    #
    #   # Do this
    #   assert_false something_that_should_be_false
    #
    # An optional +msg+ parameter is available to help you debug.
    def assert_false(boolean, message = nil)
      message = build_message message, '<?> is not false or nil.', boolean

      clean_backtrace do
        assert_block message do
          not boolean
        end
      end
    end

    # An assertion of a successful response:
    #
    #   # Instead of
    #   assert response.success?
    #
    #   # DRY that up with
    #   assert_success response
    #
    # A message will automatically show the inspection of the response
    # object if things go afoul.
    def assert_success(response, message=nil)
      clean_backtrace do
        assert response.success?, build_message(nil, "#{message + "\n" if message}Response expected to succeed: <?>", response)
      end
    end

    # The negative of +assert_success+
    def assert_failure(response, message=nil)
      clean_backtrace do
        assert !response.success?, build_message(nil, "#{message + "\n" if message}Response expected to fail: <?>", response)
      end
    end

    def assert_valid(model)
      errors = model.validate

      clean_backtrace do
        assert_equal({}, errors, "Expected to be valid")
      end

      errors
    end

    def assert_not_valid(model)
      errors = model.validate

      clean_backtrace do
        assert_not_equal({}, errors, "Expected to not be valid")
      end

      errors
    end

    def assert_deprecation_warning(message=nil)
      ActiveMerchant.expects(:deprecated).with(message ? message : anything)
      yield
    end

    def silence_deprecation_warnings
      ActiveMerchant.stubs(:deprecated)
      yield
    end

    def assert_no_deprecation_warning
      ActiveMerchant.expects(:deprecated).never
      yield
    end

    def assert_scrubbed(unexpected_value, transcript)
      refute transcript.include?(unexpected_value), "Expected #{unexpected_value} to be scrubbed out of transcript"
    end

    private
    def clean_backtrace(&block)
      yield
    rescue AssertionClass => e
      path = File.expand_path(__FILE__)
      raise AssertionClass, e.message, e.backtrace.reject { |line| File.expand_path(line) =~ /#{path}/ }
    end
  end

  module Fixtures
    HOME_DIR = RUBY_PLATFORM =~ /mswin32/ ? ENV['HOMEPATH'] : ENV['HOME'] unless defined?(HOME_DIR)
    LOCAL_CREDENTIALS = File.join(HOME_DIR.to_s, '.active_merchant/fixtures.yml') unless defined?(LOCAL_CREDENTIALS)
    DEFAULT_CREDENTIALS = File.join(File.dirname(__FILE__), 'fixtures.yml') unless defined?(DEFAULT_CREDENTIALS)

    private
    def credit_card(number = '4242424242424242', options = {})
      defaults = {
        :number => number,
        :month => 9,
        :year => Time.now.year + 1,
        :first_name => 'Longbob',
        :last_name => 'Longsen',
        :verification_value => '123',
        :brand => 'visa'
      }.update(options)

      ActiveMerchant::Billing::CreditCard.new(defaults)
    end

    def credit_card_with_track_data(number = '4242424242424242', options = {})
      defaults = {
        :track_data => '%B' + number + '^LONGSEN/L. ^15121200000000000000**123******?',
      }.update(options)

      Billing::CreditCard.new(defaults)
    end

    def address(options = {})
      {
        name:     'Jim Smith',
        address1: '1234 My Street',
        address2: 'Apt 1',
        company:  'Widgets Inc',
        city:     'Ottawa',
        state:    'ON',
        zip:      'K1C2N6',
        country:  'CA',
        phone:    '(555)555-5555',
        fax:      '(555)555-6666'
      }.update(options)
    end

    def generate_unique_id
      SecureRandom.hex(16)
    end

    def all_fixtures
      @@fixtures ||= load_fixtures
    end

    def fixtures(key)
      data = all_fixtures[key] || raise(StandardError, "No fixture data was found for '#{key}'")

      data.dup
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

MiniTest::Test.class_eval do
  #include KillBill::DirectConnect
  include DirectConnect::Assertions
  include DirectConnect::Fixtures
end