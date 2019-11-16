# frozen_string_literal: true

require "spec_helper"

MAILGUN_PORT = 20081

RSpec.describe "Mailgun API", type: :feature, browser: false, mailcatcher_options: ["--mailgun-ip", LOCALHOST, "--mailgun-port", MAILGUN_PORT.to_s] do
  def mailgun_uri(path)
    URI("http://#{LOCALHOST}:#{MAILGUN_PORT}#{path}")
  end

  def wait_for_mailgun
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until (Socket.tcp(LOCALHOST, MAILGUN_PORT, connect_timeout: 1) { true } rescue false)
    end
  end

  before { wait_for_mailgun }

  it "accepts a message and shows it in the inbox" do
    response = Net::HTTP.post_form(mailgun_uri("/v3/example.com/messages"), {
      "from" => DEFAULT_FROM,
      "to" => DEFAULT_TO,
      "subject" => "Test Mailgun Mail",
      "text" => "Plain text mailgun mail",
      "html" => "<em>HTML</em> mailgun mail",
    })
    expect(response).to be_a(Net::HTTPCreated)

    messages = JSON.parse(http_request(:get, "/messages").body)
    expect(messages.length).to eq(1)

    message = messages.first
    expect(message).to include(
      "sender" => DEFAULT_FROM,
      "recipients" => [DEFAULT_TO],
      "subject" => "Test Mailgun Mail",
    )

    plain = http_request(:get, "/messages/#{message["id"]}.plain")
    expect(plain.body).to include("Plain text mailgun mail")

    html = http_request(:get, "/messages/#{message["id"]}.html")
    expect(html.body).to include("<em>HTML</em> mailgun mail")

    count = Net::HTTP.get_response(mailgun_uri("/count"))
    expect(JSON.parse(count.body)).to eq("count" => 1)
  end
end
