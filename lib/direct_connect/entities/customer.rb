class Customer
  attr_accessor :firstname, :lastname,
                :title, :department,
                :street1, :street2, :street3,
                :city, :stateid, :province, :zip,
                :countryid, :email,
                :dayphone, :nightphone,
                :fax, :mobile, :status

    def initialize(firstname, lastname, title, department,
                   street1, street2, street3, city, stateid, province, zip,
                   countryid, email, dayphone, nightphone, fax, mobile, status)
      @firstname = firstname
      @lastname = lastname
      @title = title
      @department = department
      @street1 = street1
      @street2 = street2
      @street3 = street3
      @city = city
      @stateid = stateid
      @province = province
      @zip = zip
      @countryid = countryid
      @email = email
      @dayphone = dayphone
      @nightphone = nightphone
      @fax = fax
      @mobile = mobile
      @status = status
    end

    def customername
      @firstname + " " + @lastname
    end

end
