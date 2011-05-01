class String
  def strip2
    unless self.empty?
      lines = self.split("\n")
      indent = 0
      lines[0].each_char do |char|
        if char == " "
          indent += 1
        else
          break
        end
      end
      lines.collect{|line| line.gsub(/^([ ]{0,#{indent}})/, "")}.join("\n")
    else
      self
    end
  end
end