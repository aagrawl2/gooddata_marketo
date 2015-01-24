# encoding: UTF-8
# http://developers.marketo.com/documentation/soap/getmobjects/
require 'gooddata_marketo/models/child/criteria'
require 'gooddata_marketo/models/child/mobj'

class GoodDataMarketo::MObjects

  attr_reader :client

  def initialize config = {}

    @obj_criteria_list = []
    @client = config[:client]

  end

  def get config = {} # http://developers.marketo.com/documentation/soap/getcampaignsforsource/

    # EXAMPLE CRITERIA
    # criteria = {
    #     :attr_name => "Id", # See the types of content it can search above.
    #     :comparison => "LE",
    #     :attr_value => "1010"
    # }

    # EXAMPLE ASSOCIATED OBJECT
    # # m_associated_object = {
    #     :m_obj_type => '',
    #     :id=> '',
    #     :external_key => '' <-- Optional
    # }

    # EXAMPLE CRITERIA COMPARISONS
    # EQ - Equals
    # NE - Not Equals
    # LT - Less Than
    # LE - Less Than or Equals
    # GT - Greater Than
    # GE - Greater Than or Equals

    # ACCEPTED ATTRIBUTE VALUE ITEMS
    # Name: Name of the MObject
    # Role: The role associated with an OpportunityPersonRole object
    # Type: The type of an Opportunity object
    # Stage:- The stage of an Opportunity object
    # CRM Id: the CRM Id could refer to the Id of the Salesforce campaign connected to a Marketo program. Note: The SFDC Campaign ID needs to be the 18-digit ID.
    # Created At: Equals, not equals, less than, less than or equal to, greater than, greater than or equal to
    # Two “created dates” can be specified to create a date range
    # Updated At or Tag Type (only one can be specified): Equals, not equals, less than, less than or equal to, greater than, greater than or equal to
    # Two “created dates” can be specified to create a date range
    # Tag Value: (Only one can be specified)
    # Workspace Name: (only one can be specified)
    # Workspace Id: (only one can be specified)
    # Include Archive: Applicable only with Program MObject. Set it to true if you wish to include archived programs.

    # AVAILABLE TYPES
    # Program
    # OpportunityPersonRole
    # Opportunity

    type = config[:type] || "Program"
    request = { :type => type }

    criteria = config[:criteria] || @obj_criteria_list
    request[:m_obj_criteria_list] = criteria if criteria
    associate = config[:association] || config[:m_obj_association] || config[:associate]

    if associate
      request[:m_obj_association_list] = Hash.new
      request[:m_obj_association_list][:m_obj_association] = associate
    end

    # This field is optional and only present during `type => 'Program'` calls.
    if type == "Program"
      request[:include_details] = config[:include_details].to_s || "false"
    end

    c = client.stream(:get_m_objects, request)

    mobjects_from_call = []
    c.storage.each do |request|
      request[:m_object_list][:m_object].each do |mobj|
        m = GoodDataMarketo::MObject.new mobj
        mobjects_from_call << m
      end
    end

    binding.pry
    mobjects_from_call

  end

  def add_criteria name, value, comparison

    obj = {}
    obj[:m_obj_criteria] = {
        :attr_name => name.to_s,
        :comparison => comparison.to_s,
        :attr_value => value.to_s
    }

    @obj_criteria_list << obj

  end

  def criteria
    @obj_criteria_list
  end

  def remove_criteria query
    match = @obj_criteria_list.find {|item| item[:m_obj_criteria][:attr_name] == query }
    @obj_criteria_list.delete(match)
  end

  alias :remove :remove_criteria

  alias :add :add_criteria

end


