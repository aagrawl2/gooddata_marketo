# encoding: UTF-8

class GoodDataMarketo::Activity

  #attr_accessor :client

  def initialize data, config = {}

    data = JSON.parse(data, :symbolize_names => true) unless data.is_a? Hash

    @activity = {
        :id => data[:id],
        :activity_date_time => data[:activity_date_time].to_s, # Force this to be ADS DATETIME
        :activity_type => data[:activity_type],
        :mktg_asset_name => data[:mktg_asset_name],
        :raw => data
    }

    @headers = @activity.keys.map{|k| k.to_s.capitalize! }
    @headers.pop()

    attributes = data[:activity_attributes][:attribute]
    attribute_map = Hash.new
    attributes.map { |attr|
      @headers << property = attr[:attr_name].gsub(" ","_").downcase
                  value = StringWizard.escape_special_characters(attr[:attr_value].to_s)
                  attribute_map[property] = value
    }

    @attributes = attribute_map

  end

  def values
    hash = Hash.new
    hash['id'] = self.id
    hash['activity_date_time'] = self.time
    hash['activity_type'] = self.type
    hash['mktg_asset_name'] = self.name
    @attributes.each do |attr|
      hash[attr[0].scan(/\w+/).join] = attr[1]
    end
    hash
  end

  def time
    @activity[:activity_date_time]
  end

  def type
    @activity[:activity_type]
  end

  def to_row
    row = [self.id,self.time,self.type,self.name]
    @attributes.each do |attr|
      row << attr[1]
    end
    row.map! { |i| i.to_s }
  end

  alias :to_a :to_row

  def headers
    @headers.map { |h| h.scan(/\w+/).join.downcase }
  end

  alias :columns :headers

  def date
    @activity[:date]
  end

  def id
    @activity[:id]
  end

  def name
    @activity[:mktg_asset_name]
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

  alias :activity_date_time :time

  alias :activity_type :type

end