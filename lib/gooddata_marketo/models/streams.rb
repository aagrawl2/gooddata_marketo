# encoding: UTF-8


# http://developers.marketo.com/documentation/soap/stream-position/
require 'timeout'
require 'date'

class GoodDataMarketo::Stream

  attr_reader :client

  def initialize(web_method, request, config = {})

    def start_stream(web_method, request, config)

      @timer_start = Time.now
      puts "#{@timer_start} => Start Streaming:#{web_method}" if GoodDataMarketo.logging

      @client = config[:client]
      @storage = []

      # Make an initial call to determine what type of stream Marketo will respond with. This is based on the configurations in the initial request.
      initialized_stream = @client.call(web_method, request)
      raise "ERROR: No response from Marketo based on query: #{request}" unless initialized_stream

      begin

        # Timeout.timeout(config[:timeout] || 100){
        @storage << initialized_stream.to_json
        # }

        if initialized_stream[:new_stream_position].is_a? String
          @stream_id = initialized_stream[:new_stream_position]
          @stream_id_monitor = true
          @offset_monitor = false
        else
          initialized_stream.delete(:start_position)
          @offset_monitor = true
          @stream_id_monitor = false
          @offset = initialized_stream[:new_start_position][:offset]
        end

        @count = initialized_stream[:remaining_count].to_i

        puts "#{Time.now} => Stream:#{web_method}:#{@count} remain." if GoodDataMarketo.logging

      rescue Timeout::Error => e
        client.load.log('TIMEOUT') if client.load
        puts e if GoodDataMarketo.logging
      end

    end

    start_stream(web_method, request, config)

    @timeouts = 0
    # Begin a loop to iterate by offset or stream id depending on the stream response from Marketo.
    def next_stream_request web_method, request

      begin

        new_request = {}
        request = new_request.merge(request)

        if @stream_id
          request[:stream_position] = @stream_id
        end

        if @count < 1000
          request[:batch_size] = @count.to_s
        end

        chunk_from_stream = @client.call(web_method, request)

        @storage << chunk_from_stream.to_json

        # FOR GET LEAD ACTIVITIES. The return count and remaining count are not stacked. Request 100 and it says 8 remaining, request a batch of 8 and it says 100 remaining. No stream id.
        if chunk_from_stream[:return_count]
          @count = @count - chunk_from_stream[:return_count].to_i
        else
          @count = chunk_from_stream[:remaining_count].to_i
        end

        puts "#{Time.now} => Stream:#{web_method}:#{@count} remain." if GoodDataMarketo.logging

        if chunk_from_stream[:new_stream_position].is_a? String
          @stream_id = chunk_from_stream[:new_stream_position]
          @stream_id_monitor = true
          @offset_monitor = false
        else
          @offset_monitor = true
          @stream_id_monitor = false
          @offset = chunk_from_stream[:new_start_position][:offset]

          # Update Request
          request[:start_position] = {
              :offset => @offset
          }

        end

      rescue Error => e
        puts e if GoodDataMarketo.logging
        retry if @timeouts < 3

      end

    end

    while @count > 0
      next_stream_request web_method, request
    end

    @timer_end = Time.now
    puts "#{@timer_end} => End Streaming: #{web_method}" if GoodDataMarketo.logging
    puts "#{Time.now} => Stream duration: #{((@timer_end - @timer_start)/60).round} minutes." if GoodDataMarketo.logging

    storage_index = 0
    @storage.map! { |m|
      storage_index += 1
      puts "#{Time.now} => Hashing streams in storage: #{storage_index}" if GoodDataMarketo.logging
      JSON.parse(m, :symbolize_names => true)
    }

  end

  def storage
    @storage
  end

end

class GoodDataMarketo::SafeStream
  def initialize stream
    @stream = stream
  end
end