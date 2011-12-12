#!/usr/bin/env ruby
require "thor"
require "fileutils"
require "gluez/string"

class GluezCommand < Thor
  desc "create", "creates an gluez project"
  method_option :users, :aliases => "-u", :type => :array, :default => [], :desc => "add users to created project (separated by space)"
  method_option :apps,  :aliases => "-a", :type => :array, :default => [], :desc => "add apps to created project (separated by space)"

  def create
    ["gluez", "gluez/users", "gluez/recipes"].each do |folder|
      FileUtils.mkdir folder unless File.exists?(folder)
    end
    public_key_file = ENV['HOME'] + "/.ssh/id_rsa.pub"
    
    public_key  = File.exists?(public_key_file) ? File.read(public_key_file) : ""
    
    s = <<-EOF
      #!/usr/bin/env ruby
      require 'gluez'

      $simulate = false

      authorized_keys = [
        "#{public_key.strip}"
      ]

      context do
    EOF


    uid = 2001
    options[:users].each do |name|
      s += <<-EOF
        include_user "#{name}" do
          set :uid,               #{uid}
          set :authorized_keys,   authorized_keys
          set :sudo,              false
        end
      EOF
  
      File.open "gluez/users/#{name}.rb", "w" do |f|
        user_data = <<-EOF
          user do
          end
        EOF
        
        f.puts(user_data.multiline_strip)
      end
      
      uid += 1
    end

    s += <<-EOF
      end
    EOF

    File.open "gluez/server.rb", "w" do |f|
      f.puts(s.multiline_strip)
    end

    File.open "gluez/Vagrantfile", "w" do |f|
      code = <<-EOF
        Vagrant::Config.run do |config|
          config.vm.box = "my-ubuntu-10.10"
        end
      EOF
      f.puts(code.multiline_strip)
    end
    
    File.open "gluez/users/root.rb", "w" do |f|
      root_data = <<-EOF
        user do
        end
      EOF
      
      f.puts(root_data.multiline_strip)
    end

  end
  
end

GluezCommand.start