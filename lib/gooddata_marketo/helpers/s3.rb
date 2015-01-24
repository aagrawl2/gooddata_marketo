require 'uri'
require 'net/http'

class S3Helper

  attr_accessor :bucket_name
  attr_accessor :bucket

  def initialize config = {}

    public_key = config[:public_key]
    private_key = config[:private_key] || config[:secret_key]
    self.bucket_name = config[:bucket] || 'marketo_connector'

    AWS.config(:access_key_id => public_key, :secret_access_key => private_key)

    @s3 = AWS::S3::Client.new(region: 'us-east-1')

    bucket_exists = @s3.list_buckets.include? @bucket_name

    if bucket_exists == false
      bucket = @s3.create_bucket(:bucket_name => @bucket_name)
    else
      bucket = bucket_exists
    end

    raise 'ERROR! :public_key, :private_key must be passed for configuration.' unless public_key && private_key

  end

  def test
    begin
      self.exists? 'tmp_dumb_file'
      puts "#{Time.now} => SETUP: Connect to AWS S3 Bucket:#{self.bucket_name}...success!" if GoodDataMarketo.logging
      true
    rescue
      false
    end
  end

  def upload file
    puts "#{Time.now} => Uploading:S3_Bucket#{@bucket_name}: \"#{file}\"" if GoodDataMarketo.logging
    resp = @s3.put_object(
        data: IO.read(file),
        bucket_name: @bucket_name,
        key: file
    )
  end

  def download file
    begin
      puts "#{Time.now} => Downloading:S3_Bucket#{@bucket_name}: \"#{file}\"" if GoodDataMarketo.logging
      resp = @s3.get_object(bucket_name: @bucket_name, key:file)
      resp[:data]
    rescue
      nil
    end
  end

  def get_config config = {}

    file = config[:file] || 'marketo_connector_config.json'

    if self.exists? file
      json = JSON.parse(self.download(file), :symbolize_names => true)

      File.open(file,'w'){ |f| JSON.dump(json, f) }

      self.download(file)

      json

    else

      json = {
          :updated => Time.now.to_s,
          :initial_load_get_multiple => false,
          :initial_load_get_changes => false
      }

      File.open(file,'w'){ |f| JSON.dump(json, f) }

      self.upload(file)

      json

    end

  end

  def set_config config = {}

    if config[:file]
      file = config.delete(:file)
    else
      file = 'marketo_connector_config.json'
    end

    if self.exists? file
      json = JSON.parse(self.download(file), :symbolize_names => true)
    else
      json = Hash.new
    end

    new_json = json.merge(config)

    new_json[:updated] = Time.now.to_s

    File.open(file,'w'){ |f| JSON.dump(new_json, f) }

    self.upload(file)

    new_json

  end

  def latest_config
    if File.exists?('marketo_connector_config.json')
      File.delete('marketo_connector_config.json')
    end
    self.download('marketo_connector_config.json')
  end

  def exists? file
    begin
      @s3.get_object(bucket_name: @bucket_name, key:file)
      true
    rescue AWS::S3::Errors::NoSuchKey
      false
    end
  end

  alias :include? :exists?

  def delete file
      @s3.delete_object(bucket_name: @bucket_name, key: file)
  end


end

