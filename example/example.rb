#!/usr/bin/env ruby
require 'gluez'

$simulate = false

authorized_keys = [
  ""
]

context do
  
  include_user! "someuser" do
    set :uid,               2001
    set :authorized_keys,   authorized_keys
    set :sudo,              true
  end

  include_user "myapp" do
    set :uid,               3001
    set :authorized_keys,   authorized_keys
  end
  
end
