module Gluez
  module Impl
    class Linux
      def self.steps(cfg, task, name, opts)
        
        setup = nil
        steps = []
        
        case task
          when :gem
            steps << {
              :check  => "$(su -l #{opts[:user]} -c \"gem list | awk '{print \\$1}' | grep ^#{name}$ | wc -l\") -eq 1",
              :code   => "su -l #{opts[:user]} -c \"gem install #{name} --version #{opts[:version]} --user-install --no-rdoc --no-ri\""
            }

            name = "#{name}@#{opts[:user]}"

          when :file
            steps << {
              :check  => "-f #{name}",
              :code   => "touch #{name}"
            }

            steps << {
              :check  => "\"$(stat -L --format=%a #{name})\" = \"#{opts[:chmod, "644"]}\"",
              :code   => "chmod #{opts[:chmod, "644"]} #{name}"
            }
            
            steps << {
              :check  => "\"$(stat -L --format=%G:%U #{name})\" = \"#{opts[:chown, "root:root"]}\"",
              :code   => "chown --no-dereference #{opts[:chown, "root:root"]} #{name}"
            }

          when :dir
            steps << {
              :check  => "-d #{name}",
              :code   => "mkdir #{name}"
            }

            steps << {
              :check  => "\"$(stat -L --format=%a #{name})\" = \"#{opts[:chmod, "755"]}\"",
              :code   => "chmod #{opts[:chmod, "755"]} #{name}"
            }

            steps << {
              :check  => "\"$(stat -L --format=%G:%U #{name})\" = \"#{opts[:chown, "root:root"]}\"",
              :code   => "chown --no-dereference #{opts[:chown, "root:root"]} #{name}"
            }

          when :package
            steps << {
              :check  => "$(apt-cache policy #{name} | grep Installed | wc -l) -eq 1 && $(apt-cache policy #{name} | grep Installed | grep '(none)' | wc -l) -eq 0",
              :code   => "apt-get install #{name} --yes"
            }

          when :crontab
            default_file = "crontab.#{name}.erb"
            
            raw = File.read(cfg[:file_dir] + "/files/" + opts[:source, default_file])
            
            content = Gluez::Erb::Engine.parse(raw, opts[:vars, {}])

            setup = <<-CMD
data=$(cat <<\\DATA
#{content.strip}
DATA
)
CMD

            steps << {
              :check  => "\"$(echo -n $data | base64 -i -d | md5sum - | awk '{print $1}')\" = \"$(crontab -u #{name} -l | md5sum - | awk '{print $1}')\"",
              :code   => "echo -n $data | base64 -i -d | crontab -u #{name} -"
            }
            
          when :transfer
            default_file = name.split("/").last.gsub(/^\./, "") + ".erb"
            
            raw = File.read(cfg[:file_dir] + "/files/" + opts[:source, default_file])
            
            content = Gluez::Erb::Engine.parse(raw, opts[:vars, {}])

            setup = <<-CMD
data=$(cat <<\\DATA
#{content.strip}
DATA
)
CMD

            steps << {
              :check  => "-f #{name}",
              :code   => "touch #{name}"
            }

            steps << {
              :check  => "\"$(stat -L --format=%a #{name})\" = \"#{opts[:chmod, "644"]}\"",
              :code   => "chmod #{opts[:chmod, "644"]} #{name}"
            }

            steps << {
              :check  => "\"$(stat -L --format=%G:%U #{name})\" = \"#{opts[:chown, "root:root"]}\"",
              :code   => "chown --no-dereference #{opts[:chown, "root:root"]} #{name}"
            }

            steps << {
              :check  => "\"$(echo -n $data | base64 -i -d | md5sum - | awk '{print $1}')\" = \"$(md5sum #{name} | awk '{print $1}')\"",
              :code   => "echo -n ${data} | base64 -i -d > #{name}"
            }

          when :group
            steps << {
              :check  => "$(cat /etc/group | grep ^#{name}: | wc -l) -eq 1",
              :code   => "groupadd --gid #{opts[:gid]} #{name}"
            }

          when :user
            steps << {
              :check  => "$(cat /etc/passwd | grep ^#{name}: | wc -l) -eq 1",
              :code   => "useradd --create-home --uid #{opts[:uid]} --gid #{opts[:gid]} --shell #{opts[:shell, "/bin/bash"]} #{name}"
            }

          when :start
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"
            
            steps << {
              :check  => "\"$(grep #{name} /tmp/gluez.tmp | wc -l)\" = \"1\" && \"$(service #{name} status | grep -E 'is running|start/running' | wc -l)\" = \"1\"",
              :code   => "service #{name} start"
            }

          when :stop
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"
            steps << {
              :check  => "\"$(grep #{name} /tmp/gluez.tmp | wc -l)\" = \"1\" && \"$(service #{name} status | grep -E 'is running|start/running' | wc -l)\" = \"0\"",
              :code   => "service #{name} stop"
            }

          when :restart
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"

            steps << {
              :check  => :false,
              :code   => <<-CODE
                if [[ "$(grep #{name} /tmp/gluez.tmp | wc -l)" = "1" && "$(service #{name} status | grep -E 'is running|start/running' | wc -l)" = "1" ]]; then
                  service #{name} restart
                else
                  service #{name} start
                fi
              CODE
            }

          when :bash
            steps << {
              :check  => opts[:not_if],
              :code   => "su -l #{opts[:user, 'root']} -c '#{opts[:code]}'"
            }

          when :link
            steps << {
              :check  => "-L #{name} && $(file #{name} | grep \"#{name}: symbolic link to \\`#{opts[:target]}'\" | wc -l) -eq 1",
              :code   => "ln -f -s #{opts[:target]} #{name}"
            }
            
            steps << {
              :check  => "\"$(stat --format=%G:%U #{name})\" = \"#{opts[:chown]}\"",
              :code   => "chown --no-dereference #{opts[:chown]} #{name}"
            }

          when :enable
            steps << {
              :check  => "$(update-rc.d -n -f #{name} remove | grep '/etc/rc' | wc -l) -gt 0",
              :code   => "/usr/sbin/update-rc.d #{name} defaults"
            }

          when :disable
            steps << {
              :check  => "$(update-rc.d -n -f #{name} remove | grep '/etc/rc' | wc -l) -eq 0",
              :code   => "/usr/sbin/update-rc.d -f #{name} remove"
            }

          when :source
            user = opts[:user, "root"]
            home_dir = (user != "root") ? "/home/#{opts[:user]}" : "/root"
            
            steps << {
              :check  => "-d #{home_dir}/tmp",
              :code   => "mkdir #{home_dir}/tmp && chown #{user}:#{user} #{home_dir}/tmp"
            }

            steps << {
              :check  => opts[:test],
              :code   => <<-CODE
                [ -f #{home_dir}/tmp/#{opts[:filename]} ] && rm #{home_dir}/tmp/#{opts[:filename]}
                [ -d #{home_dir}/tmp/#{opts[:folder]} ] && rm -rf #{home_dir}/tmp/#{opts[:folder]}

                wget --no-check-certificate -O #{home_dir}/tmp/#{opts[:filename]} #{name}

                chown #{user}:#{user} #{home_dir}/tmp/#{opts[:filename]}

                tar -C #{home_dir}/tmp/ -x#{opts[:filename] =~ /\.tar\.bz2/ ? "j" : "z"}f #{home_dir}/tmp/#{opts[:filename]}

                chown -R #{user}:#{user} #{home_dir}/tmp/#{opts[:folder]}

                su -l #{user} -c 'cd #{home_dir}/tmp/#{opts[:folder]} && #{opts[:steps].join(' && ')}'

                chown -R #{user}:#{user} #{home_dir}/tmp/#{opts[:folder].split('/').first}
              CODE
            }
            
          else
            raise "unsupported task: #{task}, name: #{name}, opts: #{opts.inspect}"
        end
        
        
        [name, setup, steps]
      end
    end
  end
end