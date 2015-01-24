# encoding: UTF-8

# Jobs manages longer processes which may have failed or been terminated by the GoodData platform.

require 'gooddata_marketo/models/load'
require 'gooddata_marketo/helpers/webdav'
require 'digest/sha1'

class GoodDataMarketo::Loads

  attr_accessor :available

  def initialize config = {}

    @user = config[:user]
    @password = config[:pass] || config[:password]
    @project = config[:project] || config[:pid]
    @client = config[:marketo_client] || config[:marketo]
    @webdav = WebDAV.new :user => @user, :password => @password, :project => @project

  end

  def instantiate config = {}
    config[:webdav] = @webdav
    config[:client] = @client
    Load.new config
  end

  alias :create :instantiate

  def open file
    Load.new :file => file, :client => @client, :webdav => @webdav
  end

  def available?
    loads = Dir.entries('.').select { |f| f.include? '_load.json' }
    if loads.empty?
      false
    else
      true
      self.available = loads
    end
  end

  def upload_to_webdav file
    raise 'You must specify a :user, :password; and :project from GoodData.' unless @webdav
    @webdav.upload file
  end

  def download_from_webdav file
    raise 'You must specify a :user, :password; and :project from GoodData.' unless @webdav
    @webdav.download file

  end

end

class Load

  attr_accessor :client
  attr_accessor :storage
  attr_accessor :arguments
  attr_reader :json
  attr_reader :id

  def initialize config = {}

    @id = Digest::SHA1.hexdigest(Time.now.to_s)

    def ensure_filetype_json string
      s = string.to_s
      if s.include? '.json'
        s
      else
        s+'_load.json'
      end
    end

    file = config[:file] || config[:name]
    @file = ensure_filetype_json(file)
    @webdav = config[:webdav]
    @client = config[:client]

    # So we don't make the JSON file a mess if we merge with config.
    config.delete(:webdav)
    config.delete(:client)

    # Check to see if the file exists locally first.
    if File.exists? @file

      @json = JSON.parse(IO.read(@file), :symbolize_names => true)

    # If not is the file on WebDAV, if so, download it.
    elsif self.on_webdav?

      self.refresh

    # Otherwise create a new load file locally.
    else

      config[:id] = self.id
      File.open(@file,'w'){ |f| JSON.dump(config, f) }
      @json = config

    end

    @saved = true
    @type = @json[:type] # "leads"
    @method = @json[:method] # "get_changes"
    @arguments = @json[:arguments] || @json[:parameters] # ARGS = ":oldest_created_at => 'March 26th 2014', :filters => ['Merge Leads']"

  end

  def execute config = {}

    # Assign the current load to the client.
    client = config[:client] || @client
    client.set_load(self)

    # EXAMPLE LOADS FOR TYPE "LEADS"
    # get_lead_changes_from_march = {
    #     :name => 'get_lead_changes_from_march',
    #     :type => 'leads',
    #     :method => 'get_changes',
    #     :arguments => {
    #         :oldest_created_at => 'March 26th 2014',
    #         :latest_created_at => 'March 27th 2014',
    #         :filters => ['Merge Leads']
    #     }
    # }
    #
    # get_multiple_from_january = {
    #     :name => 'get_all_leads_january',
    #     :type => 'leads',
    #     :method => 'get_multiple',
    #     :arguments => {
    #         :oldest_created_at => 'January 1st 2014',
    #         :latest_created_at => 'January 2nd 2014',
    #         :filters => ['']
    #     }
    # }

    case @type

      when "leads"
        self.log('REQUEST')
        client.leads.send(@method, @arguments)
      else
        raise 'Unable to load JOB type (Ex. "leads").'
    end
  end

  alias :start :execute
  alias :run :execute

  # Upload the updated log to WebDAV
  def log type

    file_name = 'marketo_load_log.txt'
    log_file = File.open(file_name,'a')
    log_file.puts("#{self.id} --TYPE #{self.json[:type]} --METHOD #{self.json[:method]} --TIMESTAMP #{Time.now} --STATE #{type}")

    self.upload(file_name)

  end

  # Check if the current object "@file" is on WebDAV
  def on_webdav? f = false

    if f
      file = f
    else
      file = @file
    end

    if @webdav.exists? file
      true
    else
      false
    end

  end

  def get_argument_value key
    @arguments[key]
  end

  def set_argument_value key, value
    @arguments[key] = value
  end

  alias :get_argument :get_argument_value

  def merge_with_load load
    @json = load
  end

  def upload file=nil
    if file
      @webdav.upload file
    else
      @webdav.upload @file
    end
  end

  def refresh
    if File.exist? (@file)
      File.delete(@file)
    end
    json = @webdav.download @file
    File.open(@file,'w'){ |f| JSON.dump(json, f) }
  end

  def terminate
    # Delete on local
    File.delete(@file) if File.exists? @file

    if @webdav.exists? @file
      # Delete on remote
      @webdav.delete(@file)
    end
  end

  alias :kill :terminate

  def save

    File.open(@file,'w'){ |f| JSON.dump(@json, f) }
    @saved = true

    self.upload

  end

end