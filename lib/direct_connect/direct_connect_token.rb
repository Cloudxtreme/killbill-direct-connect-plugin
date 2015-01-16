module KillBill
  module DirectConnect
    
    ##
    # Used to pass info about a payment token that is stored in DirectConnect.
    # The token should be of type :card_safe or :stored_card
    class DirectConnectToken
      attr_reader :token
      attr_reader :type

      ##
      # Create a new payment token.
      # 
      # @param [String] token the payment token
      # @param [Symbol] type either :card_safe or :stored_card
      def initialize(token, type)
        @token = token
        @type = type
      end
      
    end
  end
end