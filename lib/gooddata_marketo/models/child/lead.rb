# encoding: UTF-8

class GoodDataMarketo::Lead

  # CLIENT OBJ REMOVED DUE TO PERFORMANCE ISSUE
  # attr_accessor :client

  def initialize data, config = {}

    data = JSON.parse(data, :symbolize_names => true) unless data.is_a? Hash

    @lead = {
        :id => data[:id],
        :email => data[:email],
        :foreign_sys_person_id => data[:foreign_sys_person_id],
        :foreign_sys_type => data[:foreign_sys_type],
        :raw => data
    }

    @headers = @lead.keys.map {|k| k.to_s.capitalize! }
    @headers.pop()

    attributes = data[:lead_attribute_list][:attribute]
    attribute_map = Hash.new
    attributes.map { |attr|
      @headers << property = attr[:attr_name].gsub(" ","_").downcase!
                  value = StringWizard.escape_special_characters(attr[:attr_value].to_s)
                  attribute_map[property] = value
    }

    @attributes = attribute_map

  end

  def to_row
    row = [self.id,self.email,self.foreign_sys_person_id,self.foreign_sys_type]
    @attributes.each do |attr|
      row << attr[1]
    end
    row.map! { |i| i.to_s }
  end

  def headers
    @headers.map { |h| h.downcase }
  end

  alias :columns :headers

  alias :to_a :to_row

  # CLIENT OBJ REMOVED DUE TO PERFORMANCE ISSUE
  # def get_activities config = {}
  #   config[:type] = 'IDNUM'
  #   config[:value] = self.id
  #
  #   client.leads.get_activities config
  #
  # end

  #alias :get_activity :get_activities
  #alias :activities :get_activities

  # CLIENT OBJ REMOVED DUE TO PERFORMANCE ISSUE
  # def get_changes config = {}
  #   config[:type] = 'IDNUM'
  #   config[:value] = self.id
  #
  #   client.leads.get_changes config
  #
  # end

  #alias :changes :get_changes

  def values
    hash = Hash.new
    hash['id'] = self.id
    hash['email'] = self.email
    hash['foreign_sys_person_id'] = self.foreign_sys_person_id
    hash['foreign_sys_type'] = self.foreign_sys_type
    @attributes.each do |attr|
      hash[attr[0]] = attr[1]
    end
    hash
  end

  def id
    @lead[:id]
  end

  def email
    @lead[:email]
  end

  def foreign_sys_person_id
    @lead[:foreign_sys_person_id]
  end

  def foreign_sys_type
    @lead[:foreign_sys_type]
  end

  def attributes a = nil

    if a
      @attributes[a]
    else
      @attributes
    end

  end

  def raw
    @lead[:raw]
  end

  alias :json :raw

end