# frozen_string_literal: true

class FalseClass
  def <=>(other)
    if other == true
      return -1
    else
      return 0
    end
  end
end

class TrueClass
  def <=>(other)
    if other == false
      return 1
    else
      return 0
    end
  end
end
