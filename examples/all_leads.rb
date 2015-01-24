#!/usr/bin/ruby

require '../lib/marketo_connector'
require 'gooddata'
require '../lib/ads/gooddata_datawarehouse'

MARKETO_USER = ""
MARKETO_KEY = ""
MARKETO_SUBDOMAIN = ''

MARKETO_AUTHORIZED_USER = ''
MARKETO_REST_SECRET = ''
MARKETO_REST_ID = ''

MARKETO_API_LIMIT = 10000 # Total number (SOAP+REST) of API calls to make in a given day.
LEAD_LIST_DUMP_CSV = 'marketo_leads_dump.csv' # Name of file to store all lead IDS.

GOODDATA_USER = 'YOU@gooddata.com'
GOODDATA_PASSWORD = ''
GOODDATA_PROJECT = ''
GOODDATA_ADS = ''

@webdav = WebDAV.new(:user => GOODDATA_USER,
                     :pass => GOODDATA_PASSWORD,
                     :project => GOODDATA_PROJECT)

@dwh = GoodData::Datawarehouse.new(GOODDATA_USER,
                                   GOODDATA_PASSWORD,
                                   GOODDATA_ADS)

@marketo = GoodDataMarketo.connect(:user_id => MARKETO_USER,
                                    :encryption_key => MARKETO_KEY,
                                    :api_subdomain => MARKETO_SUBDOMAIN,
                                    :webdav => @webdav)

GoodDataMarketo.logging = true

  ###############################
  #                             #
  #  STAGE I: GET ALL LEAD IDS  #
  #                             #
  ###############################
  # REST API download of all available leads.

marketo.write_all_lead_ids_to_csv :file => LEAD_LIST_DUMP_CSV

ids = CSV.open(LEAD_LIST_DUMP_CSV).map { |m| m[0] }

puts "#{Time.now} => #{ids.length} imported from local CSV." if GoodDataMarketo.logging

def get_all_leads_batch batch, index


  ###############################
  #                             #
  #  STAGE II: CONFIGURE LOADS  #
  #                             #
  ###############################
  # SOAP API
  # Configure additional loads as hashes, add them to @queue

  get_all_leads = {
      :name => "get_all_leads_chunk_#{index}",
      :type => 'leads',
      :method => 'get_multiple',
      :arguments => {
          :ids => batch, # Notice the addition of the IDS box
          :type => 'IDNUM'
      }
  }

  @lead_dump_file = get_all_leads[:name]

  # If there are aditional loads, add to this array.
  @queue = [get_all_leads]


  ###############################
  #                             #
  #       STAGE III: LOAD       #
  #                             #
  ###############################
  # SOAP API. No need to cofigure beyond this point.
  # Loops function until no remaining jobs.

  def determine_loads_state config = {}


    loads = @marketo.loads(:user => GOODDATA_USER,
                           :pass => GOODDATA_PASSWORD,
                           :project => GOODDATA_PROJECT,
                           :marketo_client => @marketo)

    if loads.available?

      file = loads.available.first
      load = loads.create :name => file

      # Run the load from local or remote.
      load.execute

      # Data from the job can now be accessed ARRAY load.storage
      # load.storage

      # Join all of the columns from the sample to all other columns.
      @columns_load_aggregate = ['sys_capture_date']
      load.storage.each { |lead| @columns_load_aggregate = @columns_load_aggregate | lead.columns }
      @columns_load_aggregate.map! { |column|  column.downcase.gsub('-','_') }

      # Set up a new Table/Automatically loads current table if exists.
      table = Table.new :client => @dwh, :name => 'marketo_leads', :columns => ['id','email']

      if @columns_load_aggregate.length > 0
        table.merge_columns :merge_with => @columns_load_aggregate
        @csv = CSV.open("#{@lead_dump_file}.csv", 'wb')
      else
        @csv = CSV.open("#{@lead_dump_file}.csv", 'wb')
      end

      updated_columns = table.columns

      if @columns_load_aggregate.length > 0
        @csv << updated_columns
      end

      count = 0
      load.storage.each do |lead|

        row_to_save_csv = []

        row_with_columns = updated_columns.map { |column|
          if lead.columns.include? column
            { column => lead.values[column] }
          elsif column == 'sys_capture_date'
            { 'sys_capture_date' => Time.now.to_s }
          else
            { column => "NULL" }
          end
        }

        row_with_columns.each { |item|
          c = item.to_a.flatten
          if c[1] == "NULL"
            row_to_save_csv << "NULL"
          else
            row_to_save_csv << c[1]
          end

        }

        count += 1
        @csv << row_to_save_csv

      end

      # Prepare (flush) the CSV for upload.
      @csv.flush

      table.import_csv("#{@lead_dump_file}.csv")

      puts "#{Time.now} => CSV:Rows:#{count}"
      File.delete("#{@lead_dump_file}.json")
      File.delete("#{@lead_dump_file}.csv")

      puts "#{Time.now} => ADS:TableComplete:#{@lead_dump_file}" if GoodDataMarketo.logging

      case load.json[:method]

        when 'get_changes'

          # Increment the load by one day if it is time related.
          time_increment = (12*60*60)
          oca = load.arguments[:oldest_created_at]
          lca = load.arguments[:latest_created_at]

          load.arguments[:oldest_created_at] = (Time.parse(oca) + time_increment).to_s
          load.arguments[:latest_created_at] = (Time.parse(lca) + time_increment).to_s

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

      if load
        loads.create load
        determine_loads_state
      end

    end

  end

# Run once, recursive until no loads are available.
  determine_loads_state

end

counter = 0

while ids.length > -1

  counter += 1

  batch = ids.slice!(1..1000)

  if batch.length > 0
    puts "#{Time.now} => Batch:Downloader:Length:#{batch.length} (Req:#{counter})" if GoodDataMarketo.logging
    get_all_leads_batch batch, counter

    CSV.open(LEAD_LIST_DUMP_CSV,'w') do |csv|
      ids.each { |row| csv << [row] }
    end

    next

  else

    break

  end

end

binding.pry
# table.select("SELECT * FROM #{table_name} ORDER BY id")
# SELECT * FROM marketo_leads ORDER BY id

