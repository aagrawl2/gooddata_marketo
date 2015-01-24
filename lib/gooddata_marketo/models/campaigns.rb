# encoding: UTF-8
# http://developers.marketo.com/documentation/soap/requestcampaign/

class GoodDataMarketo::Campaigns

  attr_reader :client

  def initialize config = {}

    @client = config[:client]

  end

  def get_campaign config = {}

    request = {
        :source => config[:source] || "MKTOWS",
        :campaign_id => config[:id],
        :lead_list => {
            :lead_key => {
                :key_type => config[:type] || "EMAIL",
                :key_value => config[:lead] || config[:email] || config[:id] || config[:value]
            }
        }
    }

    client.call(:request_campaign, request)
  end

  alias :request_campaign :get_campaign

  def get_campaigns_for_source config = {} # http://developers.marketo.com/documentation/soap/getcampaignsforsource/

    # Ensure exact_name key is added to request if name key.
    if config.has_key? :name
        config[:exact_name] = "false" unless config.has_key? :exact_name
    end

    default = {
        :source => "MKTOWS"
        #:name => "Trigger", <-- Optional
        #:exact_name => "false" <-- Optional
    }

    request = default.merge(config)

    client.call(:get_campaigns_for_source, request)

  end





end


