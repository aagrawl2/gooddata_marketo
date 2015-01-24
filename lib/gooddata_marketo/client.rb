 # encoding: UTF-8

begin
  verbose, $VERBOSE = $VERBOSE, nil

  dependencies = ['aws-sdk -v 1.61.0',
                  'savon -v 2.8.0',
                  'rubyntlm -v 0.3.2',
                  'gooddata -v 0.6.11',
                  'rest-client -v 1.7.2',
                  'pmap -v 1.0.2']

  puts "#{Time.now} => CheckDependencies: #{dependencies.join(', ')}" if GoodDataMarketo.logging
  dependencies.each do |dep|
    begin
      gem dep.split(' ').first
    rescue LoadError
      puts "Installing dependency #{dep}..."
      system("gem install #{dep}")
      Gem.clear_paths
      next
    end
  end

  require 'openssl'
  require 'savon'
  require 'json'
  require 'timeout'
  require 'date'
  require 'aws-sdk'
  require 'pmap'
  require 'gooddata'
  require 'gooddata_datawarehouse'

  require 'gooddata_marketo/loads'
  require 'gooddata_marketo/helpers/stringwizard'
  require 'gooddata_marketo/helpers/table'
  require 'gooddata_marketo/helpers/webdav'
  require 'gooddata_marketo/helpers/s3'

  require 'gooddata_marketo/models/leads'
  require 'gooddata_marketo/models/validate'
  require 'gooddata_marketo/models/campaigns'
  require 'gooddata_marketo/models/channels'
  require 'gooddata_marketo/models/mobjects'
  require 'gooddata_marketo/models/streams'
  require 'gooddata_marketo/models/tags'

  require 'gooddata_marketo/adapters/rest'

  require 'gooddata_marketo/data/activity_types'
  require 'gooddata_marketo/data/reserved_sql_keywords'

ensure
  $VERBOSE = verbose
end

class GoodDataMarketo::Client

  DEFAULT_CONFIG = {
      wsdl: 'http://app.marketo.com/soap/mktows/2_4?WSDL',
      read_timeout:            500,
      open_timeout:            500,
      namespace_identifier:    :ns1,
      env_namespace:           'SOAP-ENV',
      namespaces:              { 'xmlns:ns1' => 'http://www.marketo.com/mktows/' },
      pretty_print_xml:        true,
      api_subdomain:           '363-IXI-287',
      api_version:             '2_7',
      log:                     false,
      log_level:               :debug
  }

  attr_accessor :load
  attr_accessor :webdav
  attr_accessor :api_limit
  attr_accessor :activity_types

  def initialize(config = {})

    GoodDataMarketo.logging = true if config[:log]

    @api_limit = config[:api_limit] || MARKETO_API_LIMIT

    @loads = nil # Default is no jobs will be active.
    @load = nil # No job is currently set.
    @leads = nil

    config = DEFAULT_CONFIG.merge(config)

    @api_version = config.delete(:api_version).freeze
    @subdomain = config.delete(:api_subdomain).freeze
    @webdav = config.delete(:webdav)
    @logger = config.delete(:logger)

    @activity_types = ActivityTypes.new.values

    user_id = config.delete(:user_id)
    encryption_key = config.delete(:encryption_key)

    @auth = AuthHeader.new(user_id, encryption_key)

    @wsdl = "http://app.marketo.com/soap/mktows/#{@api_version}?WSDL".freeze
    @endpoint = "https://#{@subdomain}.mktoapi.com/soap/mktows/#{@api_version}".freeze

    #Create SOAP Header
    @savon = Savon.client(config.merge(endpoint: @endpoint))

    if GoodDataMarketo.logging
      puts use = self.usage
      puts "#{Time.now} => Marketo:SOAP/REST:Used of #{MARKETO_API_LIMIT}"

    end

  end

  def test_rest
    puts "#{Time.now} => SETUP: Connected to Marketo REST API:#{@subdomain}" if GoodDataMarketo.logging
    begin
      self.usage
      true
    rescue
      false
    end
  end

  def test_soap
    puts "#{Time.now} => SETUP: Connected to Marketo SOAP API:#{@subdomain}" if GoodDataMarketo.logging
    begin
      self.leads.get_by_email('test@test.com')
      true
    rescue
      false
    end
  end

  def configuration
    DEFAULT_CONFIG
  end

  def call(web_method, params, config = {}) #:nodoc:
    @api_limit -= 1
    @params = params
    @timeouts = 0
    @error = nil

    # If the time limit is up, sect the process to wait
    if @api_limit < 1

      now = DateTime.now.utc
      cst = now.in_time_zone('Central Time (US & Canada)')
      delay = (24 - cst.hours) * 2
      delay = 1 if delay == 0

      sleep (delay * 60 * 60)
      puts "#{Time.now} => API_LIMIT:Sleeping: #{delay}"

    end

    begin

      def timed_call web_method, params, config = {}

        puts "#{Time.now} => API Limit: #{@api_limit}" if GoodDataMarketo.logging
        puts "#{Time.now} => Call: #{web_method}: #{@params.to_s}" if GoodDataMarketo.logging

        Timeout.timeout(config[:timeout] || 4999) do

          response = @savon.call(
              web_method,
              message: params,
              soap_header: { 'ns1:AuthenticationHeader' => @auth.signature }
          ).to_hash

          # Add control flow to the root call because Marketo API changes for structure for just getLeadActivities
          if response[:success_get_lead_activity]
            response[:success_get_lead_activity][:lead_activity_list]
          else
            response[response.keys.first][:result]
          end

        end

      end

      timed_call web_method, @params, config

    rescue Timeout::Error => e
        @timeouts += 1

        forward_days = config[:forward_days] || 30

        def move_forward_30_days original_time, days
          smart_time = Date.parse(original_time) + days
          Time.parse(smart_time.to_s).to_s
        end

        if @params[:start_position]

          last_created_at = @params[:start_position][:last_created_at]
          latest_created_at = @params[:start_position][:latest_created_at]
          oldest_created_at = @params[:start_position][:oldest_created_at]
          last_updated_at = @params[:start_position][:last_updated_at]

          if oldest_created_at
            new_time = move_forward_30_days(oldest_created_at, forward_days)
            @params[:start_position][:oldest_created_at] = new_time
          elsif last_created_at
            new_time = move_forward_30_days(last_created_at, forward_days)
            @params[:start_position][:last_created_at] = new_time
          elsif latest_created_at
            new_time = move_forward_30_days(latest_created_at, forward_days)
            @params[:start_position][:latest_created_at] = new_time
          elsif last_updated_at
            new_time = move_forward_30_days(last_updated_at, forward_days)
            @params[:start_position][:last_updated_at] = new_time
          else
            exit
          end

          puts "#{Time.now} => #{e}:Retrying requested date +#{forward_days} days:attempts:#{@timeouts}/12" if GoodDataMarketo.logging
          retry unless @timeouts > 12

        else
          exit
        end

    end

  rescue Exception => e
    puts @error = e
    @logger.log(e) if @logger
    nil
  end

  def died(json = nil)

    if json
      file = File.open('marketo_connector_log.json','wb')
      file.write(json.to_json)
      exit
    else
      json = File.open('marketo_connector_log.json', 'r')
      json.to_h
    end

  end

  def stream(web_method, params, config = {})

    # If the stream is part of a load.

    if self.load
      "#{Time.now} => Load:#{self.load.json[:type]}:#{self.load.json[:method]}" if GoodDataMarketo.logging
    end

    puts "#{Time.now} => Stream: #{web_method}: #{params.to_s}" if GoodDataMarketo.logging

    safe = config[:safe] || true
    @timeouts = 0

    def safe_stream web_method, params, config
      begin
        #Timeout.timeout(config[:timeout] || 18000) do
        GoodDataMarketo::Stream.new web_method, params, :client => self
        #end
      rescue Timeout::Error => e
        @timeouts += 1
        puts e if GoodDataMarketo.logging
        params[:timeouts] = @timeouts
        self.load.log('TIMEOUT') if self.load
        self.died params
      end

    end

    if safe
      safe_stream web_method, params, config
    else
      GoodDataMarketo::Stream.new web_method, params, :client => self
    end


  end

  class AuthHeader #:nodoc:
    DIGEST = OpenSSL::Digest.new('sha1')
    private_constant :DIGEST

    def initialize(user_id, encryption_key)
      if user_id.nil? || encryption_key.nil?
        raise ArgumentError, ":user_id and :encryption_key required"
      end

      @user_id = user_id
      @encryption_key = encryption_key
    end

    attr_reader :user_id

    # Compute the HMAC signature and return it.
    def signature
      time = Time.now
      {
          mktowsUserId:      user_id,
          requestTimestamp:  time.to_s,
          requestSignature:  hmac(time),
      }
    end

    private
    def hmac(time)
      OpenSSL::HMAC.hexdigest(
          DIGEST,
          @encryption_key,
          "#{time}#{user_id}"
      )
    end

  end

  private_constant :AuthHeader

  def rest
    GoodDataMarketo::RESTAdapter.new :webdav => @webdav
  end

  def get_all_leads config = {}
    rest = GoodDataMarketo::RESTAdapter.new :webdav => @webdav
    rest.get_all_leads
  end

  alias :write_all_lead_ids_to_csv :get_all_leads

  def set_load load
    @load = load
  end

  def leads # http://developers.marketo.com/documentation/soap/getleadchanges/
    GoodDataMarketo::Leads.new :client => self
  end

  def usage(config = {})
    rest = GoodDataMarketo::RESTAdapter.new :webdav => @webdav
    rest.usage
  end

  def campaigns # http://developers.marketo.com/documentation/soap/campaigns/
    GoodDataMarketo::Campaigns.new :client => self
  end

  def mobjects # http://developers.marketo.com/documentation/soap/getmobjects/
    GoodDataMarketo::MObjects.new :client => self
  end

  def operations
    @savon.operations
  end

  def loads(config = {})
    self.load = true
    @loads = GoodDataMarketo::Loads.new config
  end

  def load=(load)
    @load = load
  end

  alias :objects :mobjects

  alias :lead :leads

end
