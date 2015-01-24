# encoding: UTF-8
# !!! JRUBY 1.7 REQUIRED !!!

# MARKETO CONNECTOR EXAMPLE
# Gets changes for Merge Leads since March 26th 2014. Creates a table if there is not already called leads in ADS. BULK INSERTS changed leads into leads table on ADS.

require 'pry'
require '../lib/marketo_connector'
require '../lib/ads/gooddata_datawarehouse'

MARKETO_USER = ''
MARKETO_KEY = ''
MARKETO_SUBDOMAIN = ''

GOODDATA_USER = ''
GOODDATA_PASSWORD = ''
GOODDATA_PROJECT = ''
GOODDATA_ADS  = ''

#############
#						#
#  MARKETO  #
#						#
#############

client = GoodDataMarketo.connect(:user_id => MARKETO_USER, :encryption_key => MARKETO_KEY, :api_subdomain => MARKETO_SUBDOMAIN)

changes = client.leads.get_changes(:oldest_created_at => 'March 26th 2014', :filters => ['Merge Leads'])

changed_ids = changes.map { |c| c.id }

leads = client.leads.get_multiple(:ids => changed_ids, :type => 'IDNUM')

CSV.open("tmp_leads_#{Process.pid}.csv", 'wb') do |csv|
  csv << leads.first.headers
  leads.each do |lead|
    csv << lead.to_row
  end
end

#############
#						#
#    ADS    #
#						#
#############

dwh = GoodData::Datawarehouse.new(GOODDATA_USER, GOODDATA_PASSWORD, GOODDATA_ADS)

# Set up a Table & Import BULK CSV
table = Table.new :client => dwh, :name => 'changes'
table.import_csv(file)

# File.delete(file) # Clean up

# For each change load into the leads table
count = 0

# Print the ads additions
puts 'Print tables?'
input = gets.chomp
if input == "y" || input == "yes" || input == ""
  table.select("SELECT * FROM #{table_name} ORDER BY id")
end

