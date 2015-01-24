# encoding: UTF-8

# http://developers.marketo.com/documentation/soap/gettags/

class GoodDataMarketo::Client

  attr_reader :client

  def tags config = {} # http://developers.marketo.com/documentation/soap/gettags/

    values = config[:values] || config[:value] || config[:lead]
    values = [values] if values.is_a? String

    if config[:type]
      request = {
          :tag_list => {
              :tag => {
                  :type => config[:type],
                  :values => {
                      :string_item => values
                  }
              }
          }
      }
    else
      request = {}
    end

    response = self.call(:get_tags, request)

  end

end


