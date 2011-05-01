require 'json'

require 'gluez/ext/string'

require 'gluez/option_wrapper'
require 'gluez/formatter'
require 'gluez/erb/engine'

require 'gluez/impl/linux'
# require 'gluez/impl/mac'

module Gluez

  def self.run(entries, cfg={})
    
    cfg = {
      :file_dir => "."
    }.merge(cfg)
    
    lines = []
    lines << "#!/bin/bash"
    # lines << "set -x"
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
            
      add_steps(true, lines, [], [fun, steps], notifies)
      
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
  
  def self.add_steps(first, lines, completed, steps_wrapper, notifies)
    
    fun, steps = steps_wrapper
    
    if first
      if steps.length == 2
        add_steps(false, lines, [], [fun, steps], notifies)
      else
        checks = []
        steps.each_with_index do |step, idx|
          checks << step if idx % 2 == 0
        end

        lines << "if [[ #{checks.join(' && ')} ]]; then"
        lines << "  echo \"[ #{fun} ] up2date\""
        lines << "else"
        lines << "  echo \"[ #{fun} ] NOT up2date\""
        add_steps(false, lines, [], [fun, steps], notifies)
        lines << "fi"
      end
      
    else
      check, code = steps.slice!(0,2)
      
      if check == "1 -eq 0"
        completed << "1 -eq 1"
      else
        completed << check
      end
      
      lines << "if [[ #{check} ]]; then"
      lines << "  echo \"[ #{fun} ] up2date\""
      lines << "else"
      lines << "  #{code}"
      lines << "  if [[ #{completed.join(' && ')} ]]; then"
      lines << "    echo \"[ #{fun} ] applied\""
      lines << "  else"
      lines << "    exit 1"
      lines << "  fi"
      
      lines << "fi"

      if steps.empty?
        notifies.each do |notify|
          lines << notify
        end
      else
        add_steps(false, lines, completed, [fun, steps], notifies) 
      end
    end
    
    
  end
    
end