module Gluez
  module Impl
    class Linux
      def self.steps(cfg, task, name, opts)
        
        setup = nil
        steps = []
        
        case task
          when :gem
            steps << "$(su -l #{opts[:user]} -c \"gem list | awk '{print \\$1}' | grep ^#{name}$ | wc -l\") -eq 1"
            steps << "su -l #{opts[:user]} -c \"gem install #{name} --version #{opts[:version]} --user-install --no-rdoc --no-ri\""

            name = "#{name}@#{opts[:user]}"

          when :file
            steps << "-f #{name}"
            steps << "touch #{name}"

            steps << "\"$(stat -L --format=%a #{name})\" = \"#{opts[:chmod, "644"]}\""
            steps << "chmod #{opts[:chmod, "644"]} #{name}"

            steps << "\"$(stat -L --format=%G:%U #{name})\" = \"#{opts[:chown, "root:root"]}\""
            steps << "chown --no-dereference #{opts[:chown, "root:root"]} #{name}"

          when :dir
            steps << "-d #{name}"
            steps << "mkdir #{name}"

            steps << "\"$(stat -L --format=%a #{name})\" = \"#{opts[:chmod, "755"]}\""
            steps << "chmod #{opts[:chmod, "755"]} #{name}"

            steps << "\"$(stat -L --format=%G:%U #{name})\" = \"#{opts[:chown, "root:root"]}\""
            steps << "chown --no-dereference #{opts[:chown, "root:root"]} #{name}"

          when :package
            steps << "$(apt-cache policy #{name} | grep Installed | wc -l) -eq 1 && $(apt-cache policy #{name} | grep Installed | grep '(none)' | wc -l) -eq 0"
            steps << "apt-get install #{name} --yes"

          when :transfer
            raw = File.read(cfg[:file_dir] + "/files/" + opts[:source])
            
            content = Gluez::Erb::Engine.parse(raw, opts[:vars, {}])

            setup = <<-CMD
data=$(cat <<\\DATA
#{content.strip}
DATA
)
CMD

            steps << "-f #{name}"
            steps << "touch #{name}"

            steps << "\"$(stat -L --format=%a #{name})\" = \"#{opts[:chmod, "644"]}\""
            steps << "chmod #{opts[:chmod, "644"]} #{name}"

            steps << "\"$(stat -L --format=%G:%U #{name})\" = \"#{opts[:chown, "root:root"]}\""
            steps << "chown --no-dereference #{opts[:chown, "root:root"]} #{name}"

            steps << "\"$(echo -n $data | base64 -i -d | md5sum - | awk '{print $1}')\" = \"$(md5sum #{name} | awk '{print $1}')\""
            steps << "echo -n ${data} | base64 -i -d > #{name}"

          when :group
            steps << "$(cat /etc/group | grep ^#{name}: | wc -l) -eq 1"
            steps << "groupadd --gid #{opts[:gid]} #{name}"

          when :user
            steps << "$(cat /etc/passwd | grep ^#{name}: | wc -l) -eq 1"
            steps << "useradd --create-home --uid #{opts[:uid]} --gid #{opts[:gid]} --shell #{opts[:shell, "/bin/bash"]} #{name}"

          when :start
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"
            steps << "\"$(grep #{name} /tmp/gluez.tmp | wc -l)\" = \"1\" && \"$(service #{name} status | grep -E 'is running|start/running' | wc -l)\" = \"1\""
            steps << "service #{name} start"

          when :stop
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"
            steps << "\"$(grep #{name} /tmp/gluez.tmp | wc -l)\" = \"1\" && \"$(service #{name} status | grep -E 'is running|start/running' | wc -l)\" = \"0\""
            steps << "service #{name} stop"

          when :restart
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"
            steps << "1 -eq 0"
            steps << <<-CODE
              if [[ "$(grep #{name} /tmp/gluez.tmp | wc -l)" = "1" && "$(service #{name} status | grep -E 'is running|start/running' | wc -l)" = "1" ]]; then
                service #{name} restart
              else
                service #{name} start
              fi
            CODE

          when :bash
            steps << opts[:not_if]
            steps << "su -l #{opts[:user, 'root']} -c '#{opts[:code]}'"

          when :link
            steps << "-L #{name} && $(file #{name} | grep \"#{name}: symbolic link to \\`#{opts[:target]}'\" | wc -l) -eq 1"
            steps << "ln -f -s #{opts[:target]} #{name}"
            
            steps << "\"$(stat --format=%G:%U #{name})\" = \"#{opts[:chown]}\""
            steps << "chown --no-dereference #{opts[:chown]} #{name}"

          when :enable
            steps << "$(update-rc.d -n -f #{name} remove | grep '/etc/rc' | wc -l) -gt 0"
            steps << "/usr/sbin/update-rc.d #{name} defaults"

          when :disable
            steps << "$(update-rc.d -n -f #{name} remove | grep '/etc/rc' | wc -l) -eq 0"
            steps << "/usr/sbin/update-rc.d -f #{name} remove"

          when :source
            user = opts[:user, "root"]
            home_dir = (user != "root") ? "/home/#{opts[:user]}" : "/root"
            
            steps << "-d #{home_dir}/tmp"
            steps << "mkdir #{home_dir}/tmp && chown #{user}:#{user} #{home_dir}/tmp"

            steps << "-f #{opts[:binary]}"
            steps << <<-CODE
              [ -f #{home_dir}/tmp/#{opts[:filename]} ] && rm #{home_dir}/tmp/#{opts[:filename]}
              [ -d #{home_dir}/tmp/#{opts[:folder]} ] && rm -rf #{home_dir}/tmp/#{opts[:folder]}

              wget --no-check-certificate -O #{home_dir}/tmp/#{opts[:filename]} #{name}

              chown #{user}:#{user} #{home_dir}/tmp/#{opts[:filename]}

              tar -C #{home_dir}/tmp/ -x#{opts[:filename] =~ /\.tar\.bz2/ ? "j" : "z"}f #{home_dir}/tmp/#{opts[:filename]}

              chown -R #{user}:#{user} #{home_dir}/tmp/#{opts[:folder]}

              su -l #{user} -c 'cd #{home_dir}/tmp/#{opts[:folder]} && #{opts[:steps].join(' && ')}'

              chown -R #{user}:#{user} #{home_dir}/tmp/#{opts[:folder].split('/').first}
            CODE
            
          else
            raise "unsupported task: #{task}, name: #{name}, opts: #{opts.inspect}"
        end
        
        
        [name, setup, steps]
      end
    end
  end
end