require 'spec_helper'
require 'direct_connect/fixtures'
ActiveMerchant::Billing::Base.mode = :test

describe Killbill::DirectConnect::PaymentPlugin do

  include ::Killbill::Plugin::ActiveMerchant::RSpec
  include ::DirectConnect::Fixtures

  before(:each) do
    @plugin = Killbill::DirectConnect::PaymentPlugin.new

    @account_api    = ::Killbill::Plugin::ActiveMerchant::RSpec::FakeJavaUserAccountApi.new
    @payment_api    = ::Killbill::Plugin::ActiveMerchant::RSpec::FakeJavaPaymentApi.new
    svcs            = {:account_user_api => @account_api, :payment_api => @payment_api}
    @plugin.kb_apis = Killbill::Plugin::KillbillApi.new('direct_connect', svcs)

    @call_context           = ::Killbill::Plugin::Model::CallContext.new
    @call_context.tenant_id = '00000011-0022-0033-0044-000000000055'
    @call_context           = @call_context.to_ruby(@call_context)

    @plugin.logger       = Logger.new(STDOUT)
    @plugin.logger.level = Logger::INFO
    @plugin.conf_dir     = File.expand_path(File.dirname(__FILE__) + '../../../../')
    @plugin.start_plugin

    @options = fixture_authentication

    @properties = []
    @pm         = create_payment_method(::Killbill::DirectConnect::DirectConnectPaymentMethod, nil, @call_context.tenant_id, @properties, @options)
    @amount     = BigDecimal.new('100')
    @currency   = 'USD'

    kb_payment_id = SecureRandom.uuid
    1.upto(6) do
      @kb_payment = @payment_api.add_payment(kb_payment_id)
    end
  end

  after(:each) do
    @plugin.stop_plugin
  end

  it 'should be able to charge a Credit Card directly' do
    properties = build_properties
    # We created the payment method, hence the rows
    Killbill::DirectConnect::DirectConnectResponse.all.size.should == 1
    Killbill::DirectConnect::DirectConnectTransaction.all.size.should == 0

    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE

    responses = Killbill::DirectConnect::DirectConnectResponse.all
    responses.size.should == 2
    responses[0].api_call.should == 'add_payment_method'
    responses[0].message.should == 'Successful transaction'
    responses[1].api_call.should == 'purchase'
    responses[1].message.should == 'Successful transaction'
    transactions = Killbill::DirectConnect::DirectConnectTransaction.all
    transactions.size.should == 1
    transactions[0].api_call.should == 'purchase'
  end

  it 'should be able to charge and refund' do
    @properties = build_properties
    payment_response = @plugin.purchase_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :PURCHASE

    # Try a full refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == @amount
    refund_response.transaction_type.should == :REFUND
  end

  it 'should be able to auth, capture and refund' do
    @properties = build_properties
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    # Try multiple partial captures
    partial_capture_amount = BigDecimal.new('10')
    1.upto(3) do |i|
      payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[i].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
      payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
      payment_response.amount.should == partial_capture_amount
      payment_response.transaction_type.should == :CAPTURE
    end

    # Try a partial refund
    refund_response = @plugin.refund_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[4].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    refund_response.status.should eq(:PROCESSED), refund_response.gateway_error
    refund_response.amount.should == partial_capture_amount
    refund_response.transaction_type.should == :REFUND

    # Try to capture again
    payment_response = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[5].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == partial_capture_amount
    payment_response.transaction_type.should == :CAPTURE
  end

  it 'should be able to auth and void' do
    @properties = build_properties
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.transaction_type.should == :VOID
  end

  it 'should be able to auth, partial capture and void' do
    @properties = build_properties
    payment_response = @plugin.authorize_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[0].id, @pm.kb_payment_method_id, @amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == @amount
    payment_response.transaction_type.should == :AUTHORIZE

    partial_capture_amount = BigDecimal.new('10')
    payment_response       = @plugin.capture_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[1].id, @pm.kb_payment_method_id, partial_capture_amount, @currency, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.amount.should == partial_capture_amount
    payment_response.transaction_type.should == :CAPTURE

    payment_response = @plugin.void_payment(@pm.kb_account_id, @kb_payment.id, @kb_payment.transactions[2].id, @pm.kb_payment_method_id, @properties, @call_context)
    payment_response.status.should eq(:PROCESSED), payment_response.gateway_error
    payment_response.transaction_type.should == :VOID
  end
end

def build_properties
  @options[:cc_number] = 4111111111111111  # change from 4242424242424242, which host rejects
  @options[:cc_verification_value] = 123   # change from 1234, which host rejects
  build_pm_properties(nil, @options)
end