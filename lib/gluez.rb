require 'gluez/string'

class Object
  def context(&block)
    Gluez::Context.new(&block)
  end
  def recipe(&block)
    $gluez.instance_eval(&block)
  end
  def user(&block)
    $gluez.instance_eval(&block)
  end
  def resource(name, &block)
    Gluez::Context.register(name.to_s.underscore, &block)
  end
  def role?(name)
    roles = ($roles || [])
    roles.include?(name.to_s) || roles.include?(name.to_sym)
  end
end

module Gluez
  
  def self.args()
    ARGV.select{|a| !(a =~ /^-/)}
  end

  def self.options()
    ARGV.select{|a| a =~ /^-/}
  end
  
  # Takes an array of bash code lines and returns it as a nicely formatted string.
  def self.format(lines)
    indent = 0
    num_line = 0

    prev_line = nil
    lines.split("\n").collect do |line|
      num_line += 1
      begin
        line = line.strip
      
        indent -= 2 if ['}', 'fi', 'else'].include?(line)
      
        l = (' ' * indent) + line
        indent += 2 if [/^function /, /^if /, /^else/].any?{|e| line =~ e}

        indent -= 2 if line.index('cat >~/.gluez_transfer <<\DATA')
        indent += 2 if line == 'DATA"'
      
        prev_line = line
      
        l
      rescue Exception => e
        puts "error on line: #{num_line}"
        raise e
      end
    end.join("\n")
  end  
end

$simulate = true if $simulate.nil?
$env = :development if $env.nil?

require 'gluez/resource'
require 'gluez/context'

Gluez::Context.load_resources