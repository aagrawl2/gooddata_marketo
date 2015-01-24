# encoding: UTF-8

class GoodDataMarketo::MObject

  def initialize data, config = {}

    @object = {
        :type => data[:type],
        :id => data[:id],
        :raw => data
    }

    @headers = @object.keys.map{|k| k.to_s.capitalize! }
    @headers.pop()

    attributes = data[:attrib_list][:attrib]
    attribute_map = Hash.new
    attributes.map { |attr|
      @headers << property = attr[:name]
                  value = attr[:value]
                  attribute_map[property] = value
    }

    @attributes = attribute_map

  end

  def type
    @object[:type]
  end

  def to_row
    row = [self.id,self.time,self.type,self.name]
    @attributes.each do |attr|
      row << attr[1]
    end
    row.map! { |i| i.to_s }
  end

  def headers
    @headers
  end

  def id
    @object[:id]
  end

  def attributes a = nil

    if a
      @attributes[a]
    else
      @attributes
    end

  end

  def raw
    @activity[:raw]
  end

  alias :to_a :to_row

  alias :json :raw

  alias :object_type :type

end