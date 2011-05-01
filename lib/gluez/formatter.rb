module Gluez
  class Formatter
    def self.format(lines)
      indent = 0

      prev_line = nil
      lines.split("\n").collect do |line|
        line = line.strip
        
        indent -= 2 if ['}', 'fi', 'else'].include?(line)
        
        l = (' ' * indent) + line
        indent += 2 if [/^function /, /^if /, /^else/].any?{|e| line =~ e}

        indent -= 2 if line =~ /^data=/
        indent += 2 if line == ')' && prev_line == 'DATA'
        
        prev_line = line
        
        l
      end.join("\n")
    end
  end
end