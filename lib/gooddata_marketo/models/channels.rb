class GoodDataMarketo::Client

  def channels config = {} # http://developers.marketo.com/documentation/soap/getchannels/

    values = config[:values] || config[:channels]
    if values.is_a? String
      values = [values]
    end

    request = {
        :tag => {
            :values => {
                :string_item => []
            }
        }
    }

    if values
      request[:tag][:values][:string_item] = values
    end


    self.call(:get_campaigns_for_source, request)

  end


end


