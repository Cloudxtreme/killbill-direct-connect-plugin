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

require 'fixtures'

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
end

MiniTest::Test.class_eval do
  #include KillBill::DirectConnect
  include DirectConnect::Assertions
  include DirectConnect::Fixtures
end
