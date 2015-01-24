require 'gooddata_marketo/models/child/lead'

require 'rest_client'
require 'json'
require 'csv'

class GoodDataMarketo::RESTAdapter

  attr_accessor :token
  attr_accessor :token_timer

  def initialize config = {}

    @api_limit = MARKETO_API_LIMIT
    @lead_list_dump = config[:file] || LEAD_LIST_DUMP_CSV || 'marketo_leads_dump.csv'
    @marketo_subdomain = config[:subdomain] || MARKETO_SUBDOMAIN
    @marketo_rest_secret = config[:secret] || config[:user] || MARKETO_REST_SECRET
    @marketo_rest_id = config[:id] || config[:user] || MARKETO_REST_ID
    @marketo_domain = "https://#{@marketo_subdomain}.mktorest.com"
    @webdav = config[:webdav]
    @lead_list_ids = []
    @token = self.get_token unless config[:token]
    @token_uri = "?access_token=#{@token}"

    # Example endpoint = "/rest/v1/lists.json"

  end

  # If token has existed for more than 6000 seconds, refresh it.
  def refresh_token?
    if (@token_timer + 6000) < Time.now
      self.get_token
      true
    else
      false
    end
  end

  def get url
    @api_limit -= 1
    begin
      puts "#{Time.now} => REST:GET (#{url})" if GoodDataMarketo.logging
      response = RestClient.get url
    rescue Exception => exc
      puts exc if GoodDataMarketo.logging
      puts "#{Time.now} => Possible API Limit reached, last request was  ##{@api_limit} of #{MARKETO_API_LIMIT}"
    end
  end

  def get_lead_lists next_page_token = nil

    endpoint = "/rest/v1/lists.json"
    url = @marketo_domain + endpoint + @token_uri

    if next_page_token
      endpoint = "/rest/v1/lists.json"
      url = @marketo_domain + endpoint + @token_uri + "&nextPageToken="+next_page_token
    end

    response = self.get url

    json = JSON.parse(response.body, :symbolize_names => true)

    json[:result].each { |m|  @lead_list_ids << m[:id] }

    next_page_token = json[:nextPageToken]

    if next_page_token
      self.get_lead_lists next_page_token
    else
      @lead_list_ids
    end

  end

  def get_multiple_leads config = {}

    self.refresh_token?

    ids = config[:ids] || config[:values] || [28567,30885,32240,37161,40832]
    domain = @marketo_domain
    parameters = "&filterType=id"+"&filterValues="+ids.join(',')
    endpoint= "/rest/v1/leads.json"
    url = domain + endpoint + @token_uri + parameters

    self.get url

  end

  def get_all_leads config = {}

    self.refresh_token?

    # Check if we already have a leads list, if so, download it.
    self.load_lists

    # Check if there was a stream broken while downloading a specific list.
    self.load_last_page

    # Check if there was a partial ID dump available on WebDAV, if so download it..
    self.load_id_dump

    @fields = config[:fields] || 'id'

    # For each of the lead list ids, download their respective leads by id.
    @csv = CSV.open(@lead_list_dump,'a+')

    lists = @lead_list_ids

    lists.each do |list|

      id = @lead_list_ids.shift

      domain = @marketo_domain
      parameters = "&fields=#{@fields}"
      endpoint= "/rest/v1/list/#{id}/leads.json"
      url = domain + endpoint + @token_uri + parameters

      # Conditional recursive function ends if nextPageToken is not available in response. Writes results to CSV.
      def rest_lead_stream url, list_id

        response = self.get url
        json = JSON.parse(response.body, :symbolize_names => true)
        results = json[:result]

        if results
          results.each { |result| @csv << [result[:id]] }
          @csv.flush
          puts "#{Time.now} => REST:leadList:#{list_id}:Results:#{results.length}" if GoodDataMarketo.logging
        end

        next_page_token = json[:nextPageToken]

        # If there is another page, remember it and then attempt the next load.
        if next_page_token

          self.remember_next_page :token => token, :list => list_id
          domain = @marketo_domain
          parameters = "&fields=#{@fields}"
          endpoint= "/rest/v1/list/#{list_id}/leads.json"
          url = domain + endpoint + @token_uri + parameters + "&nextPageToken=" + next_page_token
          rest_lead_stream url, list_id

        else

          # Update the local and remote lead lists
          File.open('lead_list_ids.json','w'){ |f| JSON.dump(@lead_list_ids, f) }
          @webdav.upload('lead_list_ids.json')

        end

      end

      # While on this list, check to see if it failed working on it before and resume where it left off.
      if @next_page_token_list == list

        puts "#{Time.now} => REST(Resumed):leadList:#{list}:NextPageToken:#{@next_page_token}" if GoodDataMarketo.logging
        domain = @marketo_domain
        parameters = "" #"&fields=#{fields}"
        endpoint= "/rest/v1/list/#{list}/leads.json"
        url = domain + endpoint + @token_uri + parameters + "&nextPageToken=" + @next_page_token

        rest_lead_stream url, list

      else

        rest_lead_stream url, list

      end

    end

    # Remove lists from WebDav & Local, upload Marketo Ids Dump to webdav.
    self.clean

    # Update the etl controller that an update as occured.
    self.resolve_with_etl_controller

  end

  def get_all_lead_ids config = {}
    config[:fields] = 'id'
    self.get_all_leads config
  end

  def get_all_lead_emails config = {}
    config[:fields] = 'email'
    self.get_all_leads config
  end

  def load_last_page

    if @webdav.include? 'lead_list_next_page_token.json'
      next_page_token_json = @webdav.download 'lead_list_next_page_token.json'
      json = JSON.parse(next_page_token_json)
    elsif File.exists? 'lead_list_next_page_token.json'
      json = JSON.parse( IO.read('lead_list_next_page_token.json'))
    else
      json = {}
    end

    @next_page_token = json[:token]
    @next_page_token_list = json[:list]

  end

  def load_id_dump
    # Check if the lists leads have already been dumped. Append to it.
    if @webdav.exists? @lead_list_dump
      file = @webdav.download @lead_list_dump
      puts "#{Time.now} => WEBDAV:ID_DUMP:Load" if GoodDataMarketo.logging
      f = File.open(@lead_list_dump,'w')
      f.write(file)
    end
  end

  def load_lists
    if @webdav.include? 'lead_list_ids.json'
      lists = @webdav.download 'lead_list_ids.json'
      @lead_list_ids = JSON.parse(lists)
      puts "#{Time.now} => WEBDAV:ListsLoaded:#{@lead_list_ids.length}:lead_list_ids.json" if GoodDataMarketo.logging
    else
      self.get_lead_lists
    end
  end

  def remember_next_page config = {}
    File.open('lead_list_next_page_token.json','w'){ |f| JSON.dump(config, f) }
    @webdav.upload('lead_list_next_page_token.json')
  end

  def clean

    lli = 'lead_list_ids.json'
    llnpt = 'lead_list_next_page_token.json'

    # Remove list ids from webdav and local
    if @webdav.exists?(lli)
      @webdav.delete(lli)
    end

    if @webdav.exists?(llnpt)
      @webdav.delete(llnpt)
    end

    File.delete(lli) if File.exists? lli
    File.delete(llnpt) if File.exists? llnpt

    # Upload marketo_dump to webdav for backup.
    @webdav.upload(@lead_list_dump)

  end

  def get_token


    domain = @marketo_domain
    endpoint = "/identity/oauth/token?grant_type=client_credentials"
    url = domain + endpoint + "&client_id=" + @marketo_rest_id + "&client_secret=" + @marketo_rest_secret
    response = self.get url
    results = JSON.parse(response.body)
    access_token = results["access_token"]
    @token_timer = Time.now
    @token = access_token
    access_token

  end

  def usage
    domain = @marketo_domain
    endpoint = "/rest/v1/stats/usage.json"
    url = domain + endpoint + @token_uri

    # Note this is the only rest call which does not use the log so as not to print the keys to log.
    response = RestClient.get url

    #Parse reponse and return only access token
    results = JSON.parse(response.body)['result']
  end

  def resolve_with_etl_controller

    puts 'Complete'
    # Here it would update the log that a full upload as occured.
  end

end