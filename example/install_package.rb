#!/usr/bin/env ruby

require 'gluez'

puts Gluez::run [
  [:package, 'nginx'],
  [:transfer, '/etc/nginx/nginx.conf', {
    :source => 'nginx.conf.erb',
    :vars => {
      :port => 8080
    },
    :notifies => [
      [:restart, "nginx"]
    ]
  }]
], :simulate => true