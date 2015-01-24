require 'date'

module StringWizard
  class << self

    DATE_FORMATS = ['%m/%d/%Y %I:%M:%S %p', '%Y/%m/%d %H:%M:%S', '%d/%m/%Y %H:%M', '%m/%d/%Y', '%Y/%m/%d']

    def time unparsed_time
      Time.parse(unparsed_time).to_s
      # DATE_FORMATS.each do |format|
      #   begin
      #     @time_string = Date.strptime(unparsed_time, format)
      #   rescue
      #     next
      #   end
      # end
      #
      # if @time_string.to_s.empty?
      #   nil
      # else
      #   @time_string.to_s
      # end

    end

    def escape_special_characters string
      pattern = /(\'|\*|\-|\\)/
      m = string.gsub(pattern){|match|""  + match}
      m.gsub("\n","")
    end
  end
end