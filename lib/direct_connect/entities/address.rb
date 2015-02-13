module KillBill #:nodoc:
  module DirectConnect #:nodoc:
    class Address
      attr_accessor :street1, :street2, :street3, :department, :city, :state, :province, :zip, :country

      def initialize(attributes)
        @street1 = attributes[:street1]
        @street2 = attributes[:street2]
        @street3 = attributes[:street3]
        @department = attributes[:department]
        @city = attributes[:city]
        @state = attributes[:state]
        @province = attributes[:province]
        @zip = attributes[:zip]
        @country = attributes[:country]
      end

    end
  end
end