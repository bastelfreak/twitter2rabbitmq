#!/usr/bin/ruby
# frozen_string_literal: true

# ruby extensions that we use
# more details at: http://guides.rubygems.org/what-is-a-gem/
# and http://wiki.ruby-portal.de/RubyGems
require 'uri'
require 'net/http'
require 'bunny'
require 'base64'
require 'httparty'
require 'json'

# connection settings for our rabbitmq
# replace guest/guest with the credentials that marcel and tim have
connection_details = {
  host: 'ci-slave1.virtapi.org',
  port: 5672,
  ssl: false,
  vhost: '/',
  user: 'guest',
  pass: 'guest',
  auth_mechanism: 'PLAIN'
}

# login data for twitter API
# https://developer.twitter.com/en/docs/basics/authentication/overview/application-only.html
twitter_consumer_key = ''
twitter_consumer_secret = ''


def rabbitmq_channel(connection_details)
  # connect to our rabbitmq, create a channel (something we throw messages in)
  # and afterwards subscribe to it
  # http://rubybunny.info/articles/exchanges.html
  conn = Bunny.new(connection_details)
  conn.start # establish connection to rabbitmq
  ch = conn.create_channel
  x = ch.fanout('marcelliitest')
  x
  # q = ch.queue("", :auto_delete => true).bind(x)
  # q
end

def twitter_bearer_token(consumer_key, consumer_secret)
  credentials = Base64.encode64("#{consumer_key}:#{consumer_secret}").delete("\n")
  url = 'https://api.twitter.com/oauth2/token'
  body = 'grant_type=client_credentials'
  headers = {
    'Authorization' => "Basic #{credentials}",
    'Content-Type' => 'application/x-www-form-urlencoded;charset=UTF-8'
  }
  r = HTTParty.post(url, body: body, headers: headers)
  bearer_token = JSON.parse(r.body)['access_token']
  bearer_token
end

def twitter_api_call(bearer_token, url)
  api_auth_header = { 'Authorization' => "Bearer #{bearer_token}" }
  HTTParty.get(url, headers: api_auth_header).body
end

################################################################
# Suchbegriffe als array ..
searchpattern = ['bchh17', 'jamaikasondierung', 'cop23', 'ouryjalloh', 'familiennachzug', 
'gerfra','digitalisierung', 'viagra', 'hotbabes', 'millionaire']

# Iteration / Schleife - Anfang

searchpattern.each do |local|
  twitter_api_url_we_want_to_query = 'https://api.twitter.com/1.1/search/tweets.json?q=%23' + local + 
"&count=400"


# establish connection to rabbitmq
  channel = rabbitmq_channel(connection_details)

# connect us as consumer to rabbitmq
# this allows us to retrieve incoming messages
#queue = channel.queue('', auto_delete: true).bind('marcelliitest')
#queue.subscribe do |_delivery_info, _properties, payload|

# puts "[consumer] #{queue.name} received a message: #{payload}"
# end
# connect to twitter and get the bearer token

  bearer_token = twitter_bearer_token(twitter_consumer_key, twitter_consumer_secret)
# this is a test message that we will send to the rabbitmq
# queue.publish('this is a test')

# http://i0.kym-cdn.com/entries/icons/original/000/007/582/tumblr_lmputme3co1qa6q7k_large.png
# get data from twitter, then throw it into rabbitmq
  result = twitter_api_call(bearer_token, twitter_api_url_we_want_to_query)
# print result on STDOUT
#  puts result
  json = JSON.load(result)
  statuses = json['statuses']
  statuses.each do |status|
    channel.publish(status.to_s)

  end

  t = Time.new
  puts t
  puts "Searchpattern: #{local}"
  puts "Zahl Hashtags: #{statuses.count}"
  puts
  sleep(240)

end

puts "Fertig .."
puts
