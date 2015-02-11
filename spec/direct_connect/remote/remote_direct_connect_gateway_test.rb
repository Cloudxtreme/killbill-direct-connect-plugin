$:.unshift File.dirname(__FILE__)
$:.unshift File.expand_path('../', __FILE__)
require '../test_helper'
require 'minitest/autorun'
require 'direct_connect'

class RemoteDirectConnectTest < MiniTest::Test
  def setup
    @gateway = KillBill::DirectConnect::Gateway.new(fixtures(:direct_connect))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4111111111111112')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_dump_transcript
    skip("Transcript scrubbing for this gateway has been tested.")

    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    skip "I'll (BaconSoap) fix this later"
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    cvnum_str = "cvnum=#{@credit_card.verification_value}"
    refute transcript.include?(cvnum_str), "Expected #{cvnum_str} to be scrubbed out of transcript"
    assert_scrubbed(@credit_card.number, transcript)

    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal :invalidAccountNumber, KillBill::DirectConnect::Gateway::DIRECT_CONNECT_CODES[response.params['result']]
    assert_equal 'Invalid Account Number', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response

    assert_equal :invalidAccountNumber, KillBill::DirectConnect::Gateway::DIRECT_CONNECT_CODES[response.params['result']]
    assert_equal 'Invalid Account Number', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, @credit_card, purchase.authorization, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, @credit_card, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount+1, @credit_card, purchase.authorization, @options)
    assert_failure refund
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_match 'Approved', void.message
  end

  def test_failed_void
    response = @gateway.void('')

    assert_failure response
    assert_match "Original Transaction ID Not Found", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Approved', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match "Invalid Account Number", response.message
    assert_equal :invalidAccountNumber, KillBill::DirectConnect::Gateway::DIRECT_CONNECT_CODES[response.params['result']]
  end

  def test_invalid_login
    gateway = KillBill::DirectConnect::Gateway.new(
      username: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  # crm

  def test_successful_add_customer
    response = @gateway.add_customer(@options)
    assert_success response
  end

  def test_failed_add_customer
    @options[:status] = 'xyz'
    response = @gateway.add_customer(@options)
    assert_failure response
  end

  def test_successful_update_customer
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    response = @gateway.update_customer(@options)
    assert_success response
  end

  def test_failed_update_customer
    response = @gateway.update_customer(@options)
    assert_failure response
  end

  def test_successful_delete_customer
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    response = @gateway.delete_customer(@options)
    assert_success response
  end

  def test_failed_delete_customer
    @options[:customerkey] = 123
    response = @gateway.delete_customer(@options)
    assert_failure response
  end

  def test_successful_add_credit_card_info
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    response = @gateway.add_card(@credit_card, @options)
    assert_success response
  end

  def test_failed_add_credit_card_info
    @options[:customerkey] = 123
    response = @gateway.add_card(@credit_card, @options)
    assert_failure response
  end

  def test_successful_update_credit_card_info
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    add_card_response = @gateway.add_card(@credit_card, @options)

    @options[:ccinfokey] = add_card_response.params["ccinfokey"]
    update_card_response = @gateway.update_card(@declined_card, @options)
    assert_success update_card_response
  end

  def test_failed_update_credit_card_info
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    @gateway.add_card(@credit_card, @options)

    @options[:ccinfokey] = 123
    update_card_response = @gateway.update_card(@declined_card, @options)
    assert_failure update_card_response
  end

  def test_successful_delete_credit_card_info
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    add_card_response = @gateway.add_card(@credit_card, @options)

    @options[:ccinfokey] = add_card_response.params["ccinfokey"]
    delete_card_response = @gateway.delete_card(@credit_card, @options)
    assert_success delete_card_response
  end

  def test_failed_delete_credit_card_info
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    @gateway.add_card(@credit_card, @options)

    @options[:ccinfokey] = 123
    delete_card_response = @gateway.delete_card(@credit_card, @options)
    assert_failure delete_card_response
  end

  # card safe

  def test_successful_store_card
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    response = @gateway.store_card(@credit_card, @options)
    assert_success response
  end

  def test_failed_store_card
    @options[:customerkey] = nil
    response = @gateway.store_card(@credit_card, @options)
    assert_failure response
  end

  def test_successful_process_stored_card
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    store_card_response = @gateway.store_card(@credit_card, @options)

    @options[:cardtoken] = store_card_response.params["cardtoken"]
    process_stored_card_response = @gateway.process_stored_card(@amount, @options)
    assert_success process_stored_card_response
  end

  def test_failed_process_stored_card
    @options[:cardtoken] = 123
    response = @gateway.process_stored_card(@amount, @options)
    assert_failure response
  end

  # these are the 'processcreditcard' methods under the recurring tab in the docs
  def test_successful_process_stored_card_recurring
    customer = @gateway.add_customer(@options)

    @options[:customerkey] = customer.params["customerkey"]
    add_card_response = @gateway.add_card(@credit_card, @options)

    @options[:ccinfokey] = add_card_response.params["ccinfokey"]
    process_stored_card_recurring_response = @gateway.process_stored_card_recurring(@amount, @options)
    assert_success process_stored_card_recurring_response
  end

  def test_failed_process_stored_card_recurring
    @options[:ccinfokey] = 123
    process_stored_card_recurring_response = @gateway.process_stored_card_recurring(@amount, @options)
    assert_failure process_stored_card_recurring_response
  end
end