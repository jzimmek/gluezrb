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
    # lines << "set -e"
    
    entries.each do |entry|

      task, name, opts = entry
      
      opts ||= {}
      opts = OptionWrapper.new(opts)

      name, setup, steps = Gluez::Impl::Linux.steps(cfg, task, name, opts)
      
      steps.each do |step|
        if step[:check].is_a?(Array)
          step[:check].each_with_index do |check, idx|
            step[:check][idx] = step[:check][idx].gsub("\"", "\\\"")
          end
        else
          step[:check] = step[:check].gsub("\"", "\\\"")
        end
        step[:code] = step[:code].gsub("\"", "\\\"")
      end
      
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
        generate_simulate(lines, opts[:user, 'root'], fun, steps, notifies)
      else
        generate_execute(lines, opts[:user, 'root'], fun, steps, notifies)
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
  
  def self.generate_simulate(lines, user, fun, steps, notifies)

    lines << code_check(steps, user, true)

    lines << "if [[ $? -eq 0 ]]; then"
    lines << "  echo \"[ up2date     ] #{fun}\""
    lines << "else"
    lines << "  echo \"[ not up2date ] #{fun}\""
    
    notifies.each do |notify|
      lines << notify
    end
    
    lines << "fi"
  end

  def self.code_check(steps, user, applied)
    steps.collect do |step|
      
      if step[:check].is_a?(Array)
        
        step[:check].collect do |check|
          "su -l #{user} -c \"test " + check + "\""
        end.join(" && ")
        
      else
        "su -l #{user} -c \"test " + step[:check] + "\"" unless (applied && step[:check] == '1 -eq 0')
      end
      
    end.join(" && ")
  end

  def self.generate_execute(lines, user, fun, steps, notifies)
    
    lines << code_check(steps, user, false)
    
    lines << "if [[ $? -eq 0 ]]; then"
    lines << "  echo \"[ up2date     ] #{fun}\""
    lines << "else"

    if steps.length > 1
      (0..steps.length-1).to_a.each do |limit|

        lines << code_check(steps[0..limit], user, false)

        lines << "if [[ $? -eq 0 ]]; then"
        lines << "  echo \"[ up2date     ] #{fun}\""
        lines << "else"
        
        lines << "  su -l #{user} -c \"#{steps[limit][:code]}\""

        lines << code_check(steps[0..limit], user, true)
        
        lines << "  if [[ $? -eq 0 ]]; then"
        lines << "    echo \"[ applied     ] #{fun}\""
        lines << "  else"
        lines << "    echo \"[ not applied ] #{fun}\""
        lines << "    exit 1"
        lines << "  fi"
        lines << "fi"
      end
    else
      lines << "  su -l #{user} -c \"#{steps[0][:code]}\""

      lines << code_check([steps[0]], user, true)
      
      lines << "  if [[ $? -eq 0 ]]; then"
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