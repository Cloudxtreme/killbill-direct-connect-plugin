class Address
  attr_accessor :address1, :address2, :city, :state, :zip, :country

  def initialize(address1, address2, city, state, zip, country)
    @address1 = address1
    @address2 = address2
    @city = city
    @state = state
    @zip = zip
    @country = country
  end

end
