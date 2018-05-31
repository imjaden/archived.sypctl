# encoding: utf-8
class Numeric
  def number_to_human_size(shortly = false)
    result = _to_human_size(self.to_i)
    result = result.first(2) if shortly
    result.join.strip
  end

  def _to_human_size(num, result = [], index = 0)
    human_units = ['B ', 'K ', 'M ', 'G ', 'T ', 'P ']

    if num >= 1024
      div, mod = num.divmod(1024)
      result.unshift([mod, human_units[index]])
      _to_human_size(div, result, index + 1)
    else
      result.unshift([num, human_units[index]])
    end
  end

  def number_to_human_time
    ms = (self * 1000 % 1000).to_i
    result = _to_human_time(self.to_i)
    if ms > 0
      result.clear if result.size == 2 && result.first.zero?
      result += [ms, 'ms']
    end
    result.join.strip
  end

  def _to_human_time(num, result = [], index = 0)
    human_units = ['s ', 'm ', 'h ', 'd ']

    if num >= 60
      div, mod = num.divmod(60)
      result.unshift [mod, human_units[index]]
      _to_human_time(div, result, index + 1)
    else
      result.unshift([num, human_units[index]]).flatten
    end
  end
end

