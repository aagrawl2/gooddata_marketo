require 'gooddata_marketo/data/reserved_sql_keywords'

class Table

  def initialize config = {}

    @name_of_table = config[:table] || config[:name]
    @inserts_to_object_count = 0
    @checked_columns_this_insert = false
    @dwh = config[:client]

    table_exists = @dwh.table_exists? @name_of_table
    raise 'A client is required for this module to initialize (:client => ???)' unless @dwh

    # Check if the table exists, if not, create one

    parsed_columns = self.columns_array_to_sql config[:columns]

    begin
      self.create_table parsed_columns
    rescue
      puts "#{Time.now} => #{@name_of_table} (Table) exists." if GoodDataMarketo.logging
    end

  end

  def exists? table=nil

    if table
      query = table
    else
      query = @name_of_table
    end

    @dwh.table_exists?(query)

  end

  def import_csv file_path
    puts "#{Time.now} => Loading CSV #{file_path} into ADS." if GoodDataMarketo.logging
    begin
      @dwh.load_data_from_csv(@name_of_table, file_path)
      true
    rescue Exception => exp
      puts exp if GoodDataMarketo.logging
    end

    #@dwh.csv_to_new_table(@name_of_table, file_path)
  end

  def rename new_name
    query = "ALTER TABLE #{@name_of_table} RENAME TO #{new_name}"
    @dwh.execute(query)
  end

  def bulk_insert file_path
    loc = Dir.pwd+"/"+file_path
    query = "COPY #{@name_of_table} FROM LOCAL '#{file_path}' DELIMITER ','"
    @dwh.execute(query)
  end

  def log message
    puts "#{Time.now} => #{message}" if GoodDataMarketo.logging
    message
  end

  def insert object

    row = object.to_row.map {|m|
      escaped = m.gsub("'","''")
      m = "'#{escaped}'"
    }
    row[0].to_i
    values = row.join(",")
    columns = self.columns_array_to_string(object.headers)
    self.log query = "INSERT INTO #{@name_of_table} (#{columns}) VALUES (#{values})"

    tries = 3
    begin
      @dwh.execute(query)
    rescue DataLibraryFailureException => e
      tries -= 1
      if tries > 0
        sleep 3
        retry
      else
        puts e if GoodDataMarketo.logging
      end
    end

    @checked_columns_this_insert = false

  end

  def create_table sql_columns_string
    sql_columns_string = "#{sql_columns_string}"
    # EXAMPLE sql_columns_string = "id INTEGER PRIMARY KEY, name_first VARCHAR(255), name_last VARCHAR(255)) ORDER BY id SEGMENTED BY HASH(id) ALL NODES"
    query = "CREATE TABLE #{@name_of_table} (#{sql_columns_string}) ORDER BY id SEGMENTED BY HASH(id) ALL NODES"

    puts "#{Time.now} => ADS:#{query}" if GoodDataMarketo.logging

    columns = sql_columns_string.split(', ')
    columns.map! { |column|
      s = column.split(' ')

      case s[0]
        when 'sys_capture_date' then s[1] = 'DATETIME'
        when 'activity_date_time' then s[1] = 'DATETIME'
        else  s[1] = 'VARCHAR(255)'
      end

      { :column_name => s[0], :data_type => s[1] }
    }

    puts "#{Time.now} => ADS:CreateTable:#{query}" if GoodDataMarketo.logging

    tries = 3
    begin
      @dwh.create_table(@name_of_table, columns)

    rescue Exception => exp
        puts exp if GoodDataMarketo.logging
    end

  end

  def add_column column, config = {}
    # EXAMPLE column = 'column_name'
    type = config[:type] || 'VARCHAR(255)'
    query = "ALTER TABLE #{@name_of_table} ADD COLUMN #{column} #{type}"
    puts "#{Time.now} => ADS:Query: #{query}"

    tries = 3
    begin
      @dwh.execute(query)
    rescue Exception => exp
      tries -= 1
      if tries > 0
        sleep 3

        retry
      else
        puts exp if GoodDataMarketo.logging
      end
    end

  end

  def remove_column column
    # EXAMPLE column = 'column_name'
    self.log query = "ALTER TABLE #{@name_of_table} DROP COLUMN #{column}"
    tries = 3
    begin
      @dwh.execute(query)
    rescue Exception => exp
      tries -= 1
      if tries > 0
        sleep 3
        retry
      else
        puts exp if GoodDataMarketo.logging
      end
    end
  end

  alias :drop_column :remove_column

  def columns
    @dwh.get_columns(@name_of_table).map { |column| column[:column_name] }
  end

  def select command

    rows = []
    @dwh.execute_select(command) do |row|
      puts row
      rows << row
    end
    self.log rows

  end

  alias :query :select

  def columns_array_to_string columns_string_array

    c = []
    columns_string_array.each {|a| c << a }
    id = "#{c.shift.downcase}"
    self.log columns = c.map { |column|
      "#{column.gsub(' ','').downcase}"
    }

    res = columns.unshift(id)
    res.join(', ')

  end

  def columns_array_to_sql columns_array

    c = []
    columns_array.each {|a| c << a }
    id = "#{c.shift.downcase} VARCHAR(255)"
    columns = c.map { |column|
      "#{column.gsub(' ','').downcase} VARCHAR(255)"
    }

    res = columns.unshift(id)
    res.join(', ')

  end

  def export_to_csv file_path
    tries = 3
    begin
      @dwh.export_to_csv @name_of_table, file_path
    rescue Exception => exp
      tries -= 1
      if tries > 0
        sleep 3
        retry
      else
        puts exp if GoodDataMarketo.logging
      end
    end

  end

  def check_for_sql_parse_errors text

    list = ReservedSqlKeywords.new
    keywords = list.values

    if keywords.include? text.upcase
      puts "#{Time.now} => WARNING: Updated column key \"#{text}\" to \"#{text}\" as it is a SQL reserved keyword." if GoodDataMarketo.logging
      text="#{text}_m"
    else
      text
    end

  end

  def merge_columns config = {}

    columns = config[:merge_with] || config[:columns]

    @checked_columns_this_insert = true
    # Set up Leads Table

    # Check the table columns
    current_columns = []

    if @cached_columns
      current_columns = @cached_columns
    else

      @dwh.get_columns(@name_of_table).each do |object|
        current_columns << object[:column_name]
      end

      @cached_columns = current_columns

    end

    proposed_columns = columns.map do |column|
      column.gsub(' ','').downcase
    end

    identical_columns = proposed_columns & current_columns == proposed_columns

    if identical_columns

      self.log proposed_columns

    else # Find the columns that are not in the current columns and add them.

      update_column_queue = Array.new

      proposed_columns.pmap do |check_column|

        if current_columns.find_index(check_column)
          next # Column
        else
          puts "#{Time.now} => Adding new column:#{@name_of_table}:#{check_column}" if GoodDataMarketo.logging

          check_column = self.check_for_sql_parse_errors(check_column)

          @cached_columns << check_column # Add the column to the cache

          @cached_columns.uniq!

          type = 'VARCHAR(255)'

          self.add_column(check_column, :type => type)

        end

      end

      puts "#{Time.now} => Table #{@name_of_table} Merge Complete."

      # If config BOOL = true also removed columns not found in the proposed columns in the warehouse
      if config[:two_way] || config[:sync]
        current_columns.each do |check_current_column|
          if proposed_columns.find_index(check_current_column)
            next # Column
          else
            self.log "#{Time.now} => TABLE:#{@name_of_table} + new column:#{check_current_column}"
            self.remove_column(check_current_column)
          end
        end

      end

    end

  end

  def name=
    @name_of_table
  end

end