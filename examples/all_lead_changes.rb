require 'gooddata'
require '../lib/marketo_connector'
require '../lib/ads/gooddata_datawarehouse' # Requires JRUBY

MARKETO_USER = ''
MARKETO_KEY = ''
MARKETO_SUBDOMAIN = ''

GOODDATA_USER = ''
GOODDATA_PASSWORD = ''
GOODDATA_PROJECT = ''

@marketo = GoodDataMarketo.connect(:user_id => MARKETO_USER, :encryption_key => MARKETO_KEY, :api_subdomain => MARKETO_SUBDOMAIN)

# The specific parameters used in the method.

#################
#               #
# CONFIGURATION #
#               #
#################

get_lead_changes_from_march = {
    :name => 'get_lead_changes_from_march',
    :type => 'leads',
    :method => 'get_changes',
    :arguments => {
        :oldest_created_at => 'March 26th 2014',
        :latest_created_at => 'March 27th 2014',
        :filters => ['Merge Leads']
    }
}

get_multiple_from_january = {
    :name => 'get_all_leads_january',
    :type => 'leads',
    :method => 'get_multiple',
    :arguments => {
        :ids => ['23849090','23849091'], # Notice the addition of the IDS box
        :type => 'IDNUM'
    }
}

@queue = [get_lead_changes_from_march, get_multiple_from_january]

###################################
#                                 #
# DO NOT EDIT BELOW: LOAD MANAGER #
#                                 #
###################################


def determine_loads_state

  loads = @marketo.loads(:user => GOODDATA_USER,
                         :pass => GOODDATA_PASSWORD,
                         :project => GOODDATA_PROJECT,
                         :marketo_client => @marketo)

  if loads.available?

    file = loads.available.first
    load = loads.create :name => file

    load.execute

    # Data from the job can now be accessed ARRAY load.storage
    # load.storage

    # Increment the load by one day if it is time related.

    case load.json[:method]

      when 'get_changes'

        one_day = (24*60*60)
        oca = load.arguments[:oldest_created_at]
        lca = load.arguments[:latest_created_at]

        load.arguments[:oldest_created_at] = (Time.parse(oca) + one_day).to_s
        load.arguments[:latest_created_at] = (Time.parse(lca) + one_day).to_s

        # If the latest time is later then today kill the load.
        if Time.parse(lca) > Time.now

          load.terminate

          determine_loads_state

          # Otherwise save the load and resume additional loads.
        else

          load.save

          determine_loads_state

        end

      when 'get_multiple'

        determine_loads_state

      else
        raise 'Unable to determine lead type ("get_multiple"/"get_changes")!'

    end

  else

    load = @queue.pop
    loads.create load

    determine_loads_state

  end

end

# Run once, recursive until no loads are available.
determine_loads_state

