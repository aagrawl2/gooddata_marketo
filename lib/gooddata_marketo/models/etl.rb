
class GoodDataMarketo::ETL

  def initialize config = {}
    @queue = config[:queue]
    @marketo = config[:marketo] || config[:client]
  end

  def determine_loads_state config = {}

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

          time_increment = config[:increment] || (12*60*60)
          oca = load.arguments[:oldest_created_at]
          lca = load.arguments[:latest_created_at]

          load.arguments[:oldest_created_at] = (Time.parse(oca) + time_increment).to_s
          load.arguments[:latest_created_at] = (Time.parse(lca) + time_increment).to_s

          # If the latest time is later then today kill the load.
          if Time.parse(lca) > Time.now

            load.terminate

            self.determine_loads_state

            # Otherwise save the load and resume additional loads.
          else

            load.save

            self.determine_loads_state

          end

        when 'get_multiple'

          self.determine_loads_state

        else
          raise 'Unable to determine lead type ("get_multiple"/"get_changes")!'

      end

    else

      load = @queue.pop
      loads.create load

      self.determine_loads_state

    end

  end

end