recipe do |r|
  
  default :rails_env, "development"

  expect :port
  expect :domain
  expect :rails_env

  versions = {
    :nginx => "1.0.2",
    :passenger => "3.0.7"
  }

  nginx_dir = "#{home_dir}/nginx"

  gem "passenger" do
    version   versions[:passenger]
  end
  
  bash_once "download and unpack nginx" do
    code <<-EOF
      wget --no-check-certificate -O ~/tmp/nginx-#{versions[:nginx]}.tar.gz http://nginx.org/download/nginx-#{versions[:nginx]}.tar.gz
      cd ~/tmp
      tar xzf ./nginx-#{versions[:nginx]}.tar.gz
    EOF
  end
  
  bash "install_nginx_with_passenger" do
    not_if  "-x #{nginx_dir}/sbin/nginx"
    code    "passenger-install-nginx-module --auto --nginx-source-dir=\\$HOME/tmp/nginx-#{versions[:nginx]} --prefix=#{nginx_dir} --extra-configure-flags=\\\"--with-http_ssl_module --with-http_sub_module --with-http_stub_status_module\\\""
  end
  
  ['nginx.pid', 'error.log', 'access.log'].each do |f|
    file "#{nginx_dir}/logs/#{f}" do
      chown   "#{user}:#{user}"
    end
  end
  
  transfer "/etc/init.d/nginx_#{user}" do
    as_user   "root"
    chmod     755
    content   r.read("nginx.initd.erb")
    
    var       :user,      user
    var       :nginx_dir, nginx_dir
  end
  
  enable "nginx_#{user}" do
    as_user   "root"
  end
  
  restart "nginx_#{user}" do
    as_user   "root"
    lazy true
  end
  
  transfer "#{nginx_dir}/conf/nginx.conf" do
    chmod     644
    content   r.read('nginx.conf.erb')
    
    var       :user,              user
    var       :home_dir,          home_dir
    var       :port,              r.get(:port)
    var       :domain,            r.get(:domain)
    var       :rails_env,         r.get(:rails_env)
    var       :app_root,          "#{home_dir}/app/current/public"
    var       :passenger_version, versions[:passenger]

    notify    :restart, "nginx_#{user}"
  end
  
end