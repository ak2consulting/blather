#!/usr/bin/env ruby

require 'blather/client'

when_ready { puts "Connected ! send messages to #{jid.stripped}." }

subscription :request? do |s|
  write s.approve!
end

message :chat?, :body => 'exit' do |m|
  say m.from, 'Exiting ...'
  shutdown
end

message :chat?, :body do |m|
  say m.from, "You sent: #{m.body}"
end
