class CreditCard
  attr_accessor :number, :month, :year, :first_name, :last_name, :verification_value, :brand

  def initialize (number, month, year, first_name, last_name, verification_value, brand)
    @number = number
    @month = month
    @year = year
    @first_name = first_name
    @last_name = last_name
    @verification_value = verification_value
    @brand = brand
  end

end
