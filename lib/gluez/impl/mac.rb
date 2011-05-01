module Gluez
  module Impl
    class Mac
      def self.steps(cfg, task, name, opts)
        
        setup = nil
        steps = []
        
        case task

          when :group
            steps << "$(/usr/bin/dscl . -list Groups | grep ^#{name}$ | wc -l) -eq 1"
            steps << "$(/usr/bin/dscl . -create /Groups/#{name} PrimaryGroupID #{opts[:gid]})"

          when :user
            steps << "$(/usr/bin/dscl . -list Users | grep ^#{name}$ | wc -l) -eq 1"
            steps << "$(/usr/bin/dscl . -create /Users/#{name} UniqueID #{opts[:uid]} PrimaryGroupID #{opts[:gid]} UserShell #{opts[:shell, "/bin/bash"]} NFSHomeDir /Users/#{name})"

            steps << "-d /Users/#{name}"
            steps << "mkdir /Users/#{name}"
            
            steps << "\"$(stat -L -f %Sg:%Su /Users/#{name})\" = \"#{name}:#{name}\""
            steps << "chown #{name}:#{name} /Users/#{name}"

          else
            raise "unsupported task: #{task}, name: #{name}, opts: #{opts.inspect}"
        end
        
        
        [name, setup, steps]
      end
    end
  end
end