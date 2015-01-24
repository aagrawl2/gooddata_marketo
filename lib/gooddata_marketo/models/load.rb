class GoodDataMarketo::LoadFile

  attr_accessor :name
  attr_accessor :method
  attr_accessor :type
  attr_accessor :arguments

  def initialize config = {}
    @name = config[:name]
    @type = config[:type]
    @method = config[:method]
    @arguments = {
        :ids => config[:ids] || config[:values],
        :type => config[:type]
    }
  end
end