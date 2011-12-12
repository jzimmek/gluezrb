# Gluez does a lot of text processing and maniputation. The string class is extended to dry up code. 
class String
  
  # Return the string as underscored version e.g. SomeTextValue becomes some_text_value.
  def underscore
    word = self.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end
  
  def multiline_strip
    lines = self.split("\n")
    first = lines[0]
    
    idx = 0
    while first[idx] == ' '
      idx += 1
    end
    
    if idx > 0
      lines = lines.map do |line|
        line[idx, line.length]
      end
    end
    
    lines.join("\n")
  end
  
  # Return the string as camelcased version e.g. some_text_value becomes SomeTextValue.
  def camelize(first_letter_in_uppercase=true)
    word = self.dup
    if first_letter_in_uppercase
      word.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
    else
      word.to_s[0].chr.downcase + word.camelize[1..-1]
    end
  end
  
end