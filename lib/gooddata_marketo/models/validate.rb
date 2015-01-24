# encoding: UTF-8

class GoodDataMarketo::Validate
  def initialize config

    default = {
        :backend => 'ads'
    }
    config = default.merge(config)

  end

end

# require 'rubygems'
# require 'sequel'
# require 'jdbc/dss'
#
# results = []
# tables = []
# final = []
#
# Jdbc::DSS.load_driver
# Java.com.gooddata.dss.jdbc.driver.DssDriver
#
# url1 = "jdbc:dss://secure.gooddata.com/gdc/dss/instances/df963b44d7b8a90494ad29e978039a52"
# username = ''
# password = ''
#
# Sequel.connect url1, :username => username, :password => password do |conn|
#   results = conn.fetch "select t.table_name, c.column_name, c.data_type
# 				from tables t
# 				join columns c on c.table_name = t.table_name
# 				order by t.table_name"
# end
#
# binding.pry
# #put results in array, not table thing that I don't understand
# results.each do |row|
#   tables.push([row[:table_name],row[:column_name],row[:data_type]])
# end
# puts "Printing tables having columns with numeric datatypes"
# tables.each do |table|
#   final << table[0] if table[2].include?('numeric')
# end
# puts final.uniq