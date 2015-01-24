
class GoodDataMarketo::Criteria
  def initialize name, value, comparison = nil
    @name = name
    @value = value
    @comparison = comparison
  end
  def data
    obj = {}
    o[:m_obj_criteria] = {
        :attr_name => @name,
        :comparison => @comparison,
        :attr_value => @value
    }
    obj
  end
end