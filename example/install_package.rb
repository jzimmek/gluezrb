require 'gluez'

puts Gluez::run [
  [:package, 'nginx'],
  [:transfer, '/etc/nginx/nginx.conf', {
    :source => 'nginx.conf.erb',
    :vars => {
      :port => 8080
    }
  }]
]