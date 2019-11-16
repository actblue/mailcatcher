# frozen_string_literal: true

require "json"

require "mail"
require "rack/builder"
require "sinatra/base"

require "mail_catcher/mail"

module MailCatcher
  module Mailgun extend self
    class Application < Sinatra::Base
      set :environment, MailCatcher.env

      get "/" do
        "ok"
      end

      get "/count" do
        count = MailCatcher::Mail.messages.count
        puts "*** message count #{count}"
        content_type :json
        JSON.generate(count: count)
      end

      post "/v3/:domain/messages" do
        puts "==> Mailgun: Received message from '#{params[:from]}' to '#{params[:to]}', subject: '#{params[:subject]}'"
        mail = ::Mail.new do |mail|
          mail.to params[:to]
          mail.from params[:from]
          mail.subject params[:subject]
          mail.text_part do |part|
            part.body params[:text]
          end
          mail.html_part do |part|
            part.body params[:html]
          end
        end
        MailCatcher::Mail.add_message(
          sender: params[:from],
          recipients: Array(params[:to]),
          source: mail.to_s,
        )
        MailCatcher::Mail.delete_older_messages!
        status 201
      end

      not_found do
        puts "*** 404 at #{request.path} ***"
      end
    end

    def app
      @@app ||= Rack::Builder.new do
        map("/") do
          run Application
        end
      end
    end

    def call(env)
      app.call(env)
    end
  end
end
