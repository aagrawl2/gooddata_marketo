require 'uri'
require 'net/http'

class WebDAV

	attr_accessor :project
	attr_accessor :user
	attr_accessor :password

	def initialize config = {}

		self.user = config[:user]
		self.password = config[:pass] || config[:password]
		self.project = config[:project] || config[:pid]

		raise 'ERROR! :user, :password, & :project must be passed in the configuration.' unless self.user && self.project && self.password

		@uri = URI.parse("https://secure-di.gooddata.com/project-uploads/")

	end

	def test
		begin
			test = self.exists? 'file'
			puts "#{Time.now} => SETUP: Connect to GoodData WebDAV...success!" if GoodDataMarketo.logging
			true
		rescue
			false
		end
	end

	def upload file
		http = Net::HTTP.new(@uri.host, @uri.port)
		http.use_ssl = @uri.scheme == 'https'

		request = Net::HTTP::Put.new("#{@uri.request_uri}/#{file}")
		request.basic_auth self.user, self.password
		request.body_stream = File.open(file)
		request["Content-Type"] = "multipart/form-data"
		request.add_field('Content-Length', File.size(file))

		response = http.request(request)
		if response.is_a?(Net::HTTPSuccess)
			response
		else
			false
		end

	end

	def download file
		Net::HTTP.start(@uri.host, @uri.port,
										:use_ssl => @uri.scheme == 'https') do |http|
			request = Net::HTTP::Get.new @uri+file
			request.basic_auth self.user, self.password

			response = http.request request
			if response.is_a?(Net::HTTPSuccess)
				response.body
			else
				false
			end
		end

	end

	def get_marketo_etl_controller
		self.download('marketo_connector.json')
	end

	def set_marketo_etl_controller
		self.upload('marketo_connector.json')
	end

	def exists? file

		Net::HTTP.start(@uri.host, @uri.port,
										:use_ssl => @uri.scheme == 'https') do |http|

			request = Net::HTTP::Get.new "#{@uri.to_s}#{file}/"
			request.basic_auth self.user, self.password

			response = http.request request
			if response.is_a?(Net::HTTPSuccess)
				if response.code == "200"
					true
				else
					false
				end
			else
				false
			end
		end

	end

	alias :include? :exists?

	def delete file
		Net::HTTP.start(@uri.host, @uri.port,
										:use_ssl => @uri.scheme == 'https') do |http|

			request = Net::HTTP::Delete.new @uri+file
			request.basic_auth self.user, self.password

			response = http.request request
			if response.is_a?(Net::HTTPSuccess)
				response.body
			else
				false
			end
		end

	end


end

