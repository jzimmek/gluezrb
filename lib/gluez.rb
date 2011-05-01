require 'gluez/ext/string'

require 'gluez/option_wrapper'
require 'gluez/formatter'
require 'gluez/erb/engine'

require 'gluez/impl/linux'

module Gluez

  def self.run(entries, cfg={})
    
    cfg = {
      :file_dir => ".",
      :simulate => false
    }.merge(cfg)
    
    lines = []
    lines << "#!/bin/bash"
    lines << "set -e"
    
    entries.each do |entry|

      task, name, opts = entry
      
      opts ||= {}
      opts = OptionWrapper.new(opts)

      name, setup, steps = Gluez::Impl::Linux.steps(cfg, task, name, opts)
      entry[1] = name

      fun = function_name(task, name)

      lines << "function #{fun} {"
      lines << setup if setup
      
      notifies = []
      opts[:notifies, Array.new].each do |notify|
        notify_task, notify_name = notify
        notify_fun = function_name(notify_task, notify_name)
        
        notifies << notify_fun
        
        unless entries.detect{|entry| entry[0] == notify_task && entry[1] == notify_name}
          entries << [notify_task, notify_name, {:embedded => true}]
        end
      end
      
      if cfg[:simulate]
        generate_simulate(lines, fun, steps, notifies)
      else
        generate_execute(lines, fun, steps, notifies)
      end
      
      lines << "}"
      
    end    

    entries.each do |entry|
      task, name, opts = entry
      opts ||= {}
      
      lines << function_name(task, name) unless opts[:embedded]
    end
    
    Formatter.format(lines.join("\n"))
  end
  
  private
  
  def self.function_name(task, name)
    "#{task}_#{name}".gsub('/', '_').gsub(':', '_').gsub("@", "_").gsub("~", "_").gsub(".", "_")
  end
  
  def self.generate_simulate(lines, fun, steps, notifies)

    lines << "if [[ #{steps.collect{|s| s[:check] == :false ? '1 -eq 0' : s[:check]}.join(' && ')} ]]; then"
    lines << "  echo \"[ up2date     ] #{fun}\""
    lines << "else"
    lines << "  echo \"[ not up2date ] #{fun}\""
    
    notifies.each do |notify|
      lines << notify
    end
    
    lines << "fi"
  end
  
  def self.generate_execute(lines, fun, steps, notifies)
    
    lines << "if [[ #{steps.collect{|s| s[:check] == :false ? '1 -eq 0' : s[:check]}.join(' && ')} ]]; then"
    lines << "  echo \"[ up2date     ] #{fun}\""
    lines << "else"

    if steps.length > 1
      (0..steps.length-1).to_a.each do |limit|
        lines << "if [[ #{steps[0..limit].collect{|s| s[:check] == :false ? '1 -eq 0' : s[:check]}.join(' && ')} ]]; then"
        lines << "  echo \"[ up2date     ] #{fun}\""
        lines << "else"
        lines << "  #{steps[limit][:code]}"
        lines << "  if [[ #{steps[0..limit].collect{|s| s[:check] == :false ? '1 -eq 0' : s[:check]}.join(' && ')} ]]; then"
        lines << "    echo \"[ applied     ] #{fun}\""
        lines << "  else"
        lines << "    echo \"[ not applied ] #{fun}\""
        lines << "    exit 1"
        lines << "  fi"
        lines << "fi"
      end
    else
      lines << "  #{steps[0][:code]}"
      lines << "  if [[ #{steps[0][:check] == :false ? '1 -eq 1' : steps[0][:check]} ]]; then"
      lines << "    echo \"[ applied     ] #{fun}\""
      lines << "  else"
      lines << "    echo \"[ not applied ] #{fun}\""
      lines << "    exit 1"
      lines << "  fi"
    end
    
    notifies.each do |notify|
      lines << notify
    end
    
    lines << "fi"
  end
    
end