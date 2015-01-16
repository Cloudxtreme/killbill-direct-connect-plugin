$:.unshift File.dirname(__FILE__)
$:.unshift File.expand_path('../', __FILE__)
require '../test_helper'
require 'minitest/autorun'
require 'direct_connect'

class RemoteDirectConnectTest < MiniTest::Test
  def setup
    @customer_id = 'b2a4dadc-8def-4623-96a2-da0c80b63ad4'
    @customer_key = '661887'
    @creds = fixtures(:direct_connect)
    @gateway = KillBill::DirectConnect::Gateway.new(@creds)

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4111111111111112')
    @token = KillBill::DirectConnect::DirectConnectToken.new(11153405, :stored_card)

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

  # recurring

  def test_successful_add_contract
    contract = {
      :period => :day,
      :interval => 1,
      :start_date => '01/16/2015',
      :end_date => '01/30/2015',
      :next_bill_date => '01/17/2015',
      :amount => {
        :bill => 100,
        :tax => 0,
        :total => 100
      },
      :contract_id => 12345654321,
      :name => 'test contract'
    }
    customer = {
      :key => @customer_key,
      :name => 'Person Man'
    }

    @options[:customer] = customer
    @options[:contract] = contract
    @options[:vendor] = @creds[:vendorid]
    response = @gateway.add_contract(@token, @options)
    contract_key = response.params['contractkey'].to_i # this is the contract key
    assert_success response
  end

  def test_failed_add_contract
    contract = {
      :period => :day,
      :interval => 1,
      :start_date => '01/16/2015',
      :end_date => '01/30/2015',
      :next_bill_date => '01/17/2015',
      :amount => {
        :bill => 100,
        :tax => 0,
        :total => 100
      },
      :name => 'test contract'
    }
    customer = {
      :name => 'Person Man'
    }

    @options[:customer] = customer
    @options[:contract] = contract
    @options[:vendor] = @creds[:vendorid]
    response = @gateway.add_contract(@token, @options)
    assert_failure response
  end

  def test_successful_update_contract
  end

  def test_failed_update_contract
  end

  def test_successful_delete_contract
  end

  def test_failed_delete_contract
  end

  # crm

  def test_successful_add_customer
  end

  def test_failed_add_customer
  end

  def test_successful_update_customer
  end

  def test_failed_update_customer
  end

  def test_successful_delete_customer
  end

  def test_failed_delete_customer
  end

  def test_successful_add_credit_card_info
  end

  def test_failed_add_credit_card_info
  end

  def test_successful_update_credit_card_info
  end

  def test_failed_update_credit_card_info
  end

  def test_successful_delete_credit_card_info
  end

  def test_failed_delete_credit_card_info
  end

  # card safe

  def test_successful_store_card
  end

  def test_failed_store_card
  end

  def test_successful_process_stored_card
  end

  def test_failed_process_stored_card
  end

  # these are the 'processcreditcard' methods under the recurring tab in the docs
  def test_successful_process_stored_card_recurring
  end

  def test_successful_process_stored_card_recurring
  end
end