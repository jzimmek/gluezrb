recipe do
  
  default :version, "1.9.2-p290"
  expect :version
  
  version = get(:version)
  
  source "ftp://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.bz2" do
    filename  "ruby-#{version}.tar.bz2"
    folder    "ruby-#{version}"
    make      "./configure --prefix=#{home_dir}/ruby-#{version} && make && make install"
    not_if    "-x ~/ruby-#{version}/bin/ruby"
  end
  
  link "~/ruby" do
    target "~/ruby-#{version}"
  end

  path "~/ruby/bin"

  path "~/.gem/ruby/1.9.1/bin"
  
  # bash_once "compile ruby openssl" do
  #   code <<-EOF
  #     cd ~/tmp/ruby-#{version}/ext/openssl/
  #     ~/ruby/bin/ruby extconf.rb
  #     make && make install
  #   EOF
  # end
  
end