module KillBill #:nodoc:
  module DirectConnect #:nodoc:
    class Customer
      attr_accessor :firstname, :lastname,
                    :title, :address,
                    :email, :dayphone, :nightphone,
                    :fax, :mobile, :status,
                    :customerkey, :customerid

      def initialize(attributes)
        @firstname = attributes[:firstname]
        @lastname = attributes[:lastname]
        @title = attributes[:title]
        @address = Address.new(attributes)
        @email = attributes[:email]
        @dayphone = attributes[:dayphone]
        @nightphone = attributes[:nightphone]
        @fax = attributes[:fax]
        @mobile = attributes[:mobile]
        @status = attributes[:status]
        @customerkey = nil
        @customerid = nil
      end

      def customername
        @firstname.to_s + " " + @lastname.to_s
      end

    end
  end
end