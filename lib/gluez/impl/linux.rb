module Gluez
  module Impl
    class Linux
      def self.steps(cfg, task, name, opts)
        
        setup = nil
        steps = []
        
        case task
          when :gem
            steps << {
              :check  => "\\$(gem list | awk '{print \\$1}' | grep ^#{name}$ | wc -l) -eq 1",
              :code   => "gem install #{name} --version #{opts[:version]} --user-install --no-rdoc --no-ri"
            }

          when :file
            steps << {
              :check  => "-f #{name}",
              :code   => "touch #{name}"
            }

            steps << {
              :check  => %Q("\\$(stat -L --format=%a #{name})" = "#{opts[:chmod, "644"]}"),
              :code   => "chmod #{opts[:chmod, "644"]} #{name}"
            }
            
          when :dir
            steps << {
              :check  => "-d #{name}",
              :code   => "mkdir #{name}"
            }

            steps << {
              :check  => %Q("\\$(stat -L --format=%a #{name})" = "#{opts[:chmod, "755"]}"),
              :code   => "chmod #{opts[:chmod, "755"]} #{name}"
            }

          when :package
            steps << {
              :check  => [
                "\\$(apt-cache policy #{name} | grep Installed | wc -l) -eq 1",
                "\\$(apt-cache policy #{name} | grep Installed | grep '(none)' | wc -l) -eq 0"
              ],
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
              :check  => %Q("\\$(echo -n $data | base64 -i -d | md5sum - | awk '{print $1}')" = "\\$(crontab -u #{name} -l | md5sum - | awk '{print $1}')"),
              :code   => "echo -n $data | base64 -i -d | crontab -u #{name} -"
            }
            
          when :transfer
            default_file = name.split("/").last.gsub(/^\./, "") + ".erb"
            
            raw = File.read(cfg[:file_dir] + "/files/" + opts[:source, default_file])
            
            content = Gluez::Erb::Engine.parse(raw, opts[:vars, {}])

            setup = <<-CMD
su -l #{opts[:user, 'root']} -c "cat >~/.gluez_transfer <<\\DATA
#{content.strip}
DATA
"
CMD

            steps << {
              :check  => "-f #{name}",
              :code   => "touch #{name}"
            }

            steps << {
              :check  => %Q("\\$(stat -L --format=%a #{name})" = "#{opts[:chmod, "644"]}"),
              :code   => "chmod #{opts[:chmod, "644"]} #{name}"
            }

            steps << {
              :check  => %Q("\\$(cat ~/.gluez_transfer | base64 -i -d - | md5sum - | awk '{print \\$1}')" = "\\$(md5sum #{name} | awk '{print \\$1}')"),
              :code   => "chmod +w #{name} && cat ~/.gluez_transfer | base64 -i -d - > #{name} && chmod #{opts[:chmod, "644"]} #{name}"
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
              :check  => [
                %Q("\\$(grep #{name} /tmp/gluez.tmp | wc -l)" = "1"),
                %Q("\\$(service #{name} status | grep -E 'is running|start/running' | wc -l)" = "1")
              ],
               
              :code   => "service #{name} start"
            }

          when :stop
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"
            steps << {
              :check  => [
                %Q("\\$(grep #{name} /tmp/gluez.tmp | wc -l)" = "1"),
                %Q("\\$(service #{name} status | grep -E 'is running|start/running' | wc -l)" = "0"),
              ],
              :code   => "service #{name} stop"
            }

          when :restart
            setup = "service --status-all 1>/tmp/gluez.tmp 2>&1"

            steps << {
              :check  => '1 -eq 0',
              :code   => "service #{name} restart"
            }

          when :bash
            steps << {
              :check  => opts[:not_if],
              :code   => opts[:code]
            }
            
          when :bash_once
            home_dir = (opts[:user, 'root'] == 'root') ? "/root" : "/home/#{opts[:user, 'root']}"
            steps << {
              :check  => "-f #{home_dir}/.gluez/#{name}",
              :code   => opts[:code] + "\n" + "touch #{home_dir}/.gluez/#{name}"
            }

          when :bundler
            steps << {
              :check    => "\"\\$(cd #{name} && bundle check > /dev/null && echo 'up2date')\" = \"up2date\"",
              :code     => "cd #{name} && bundle install"
            }
          
          when :umount
            steps << {
              :check  => "\\$(mount | grep \"on #{name} type\" | wc -l) -eq 0",
              :code   => "umount #{name}"
            }
            
          when :mount
            
            cmd = "mount -t #{opts[:type]}"
            cmd = "#{cmd} -o #{opts[:options]}" if opts.key?(:options)
            cmd = "#{cmd} #{opts[:device]} #{name}"
            
            steps << {
              :check  => "\\$(mount | grep \"on #{name} type\" | wc -l) -eq 1",
              :code   => cmd
            }

          when :link
            steps << {
              :check  => [
                "-L #{name}",
                "\\$(file #{name} | grep \"#{name.gsub('~', '\$HOME')}: symbolic link to \\\\\\`#{opts[:target].gsub('~', '\$HOME')}'\" | wc -l) -eq 1"
              ],
              :code   => "ln -f -s #{opts[:target]} #{name}"
            }
            
          when :enable
            steps << {
              :check  => "\\$(update-rc.d -n -f #{name} remove | grep '/etc/rc' | wc -l) -gt 0",
              :code   => "/usr/sbin/update-rc.d #{name} defaults"
            }

          when :disable
            steps << {
              :check  => "\\$(update-rc.d -n -f #{name} remove | grep '/etc/rc' | wc -l) -eq 0",
              :code   => "/usr/sbin/update-rc.d -f #{name} remove"
            }

          when :source
            user = opts[:user, "root"]
            home_dir = (user != "root") ? "/home/#{opts[:user]}" : "/root"
            
            steps << {
              :check  => "-d ~/tmp",
              :code   => "mkdir ~/tmp"
            }

            steps << {
              :check  => opts[:test],
              :code   => <<-CODE
                [ -f ~/tmp/#{opts[:filename]} ] && rm ~/tmp/#{opts[:filename]}
                [ -d ~/tmp/#{opts[:folder]} ] && rm -rf ~/tmp/#{opts[:folder]}

                wget --no-check-certificate -O ~/tmp/#{opts[:filename]} #{name}
                tar -C ~/tmp/ -x#{opts[:filename] =~ /\.tar\.bz2/ ? "j" : "z"}f ~/tmp/#{opts[:filename]}
                cd ~/tmp/#{opts[:folder]} && #{opts[:steps].join(' && ')}
              CODE
            }
            
          else
            raise "unsupported task: #{task}, name: #{name}, opts: #{opts.inspect}"
        end

        name = "#{name}@#{opts[:user]}" if opts.key?(:user)
        
        [name, setup, steps]
      end
    end
  end
end