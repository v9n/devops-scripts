# Fetch pagerduty incident and store into RethinkDB for analytics
require 'httparty'
require 'json'
require 'pp'
require 'rethinkdb'

module DevOps
  module Script
    class Writer
      include RethinkDB::Shortcut
    end

    class Pagerduty
      SUBDOMAIN = ENV['DOMAIN']
      API_TOKEN = ENV["PD"]
      ENDPOINT = "https://#{SUBDOMAIN}.pagerduty.com/api/v1/incidents/"
      TOKEN_STRING = "Token token=#{API_TOKEN}"
      USER_ID = ENV['USER_ID']

      def initialize()
      end

      def incidents
        puts "request pd", ENDPOINT, TOKEN_STRING

        response = HTTParty.get(
          ENDPOINT + "?statuses[]=triggered&statuses[]=resolved" ,
          headers: {
            'Content-Type' => 'application/json', 'Authorization' => TOKEN_STRING
          }
        )
        JSON.parse response.body
      end

      def poll
        pagerduty_th =  Thread.new do
          loop do
            begin
              incidents.each do |incident|
                  puts "Found "
                  puts incident
              end
            rescue => e
              puts "Error"
              pp e
              sleep 1
            end
            sleep 10
          end
        end
        [pagerduty_th].map(&:join)
      end
    end
  end
end

p = DevOps::Script::Pagerduty.new
p.poll
