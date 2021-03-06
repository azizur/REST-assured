$:.push File.expand_path('../../../lib', __FILE__)
require 'rubygems'
require 'spork'

Spork.prefork do
  require 'timeout'
  require 'rspec'
  require 'rack/test'
  require 'capybara'
  require 'capybara/cucumber'
  require 'database_cleaner'
  require 'anticipate'
  require 'awesome_print'
  require 'rest-assured/utils/port_explorer'
  require File.dirname(__FILE__) + '/world_helpers'

  ENV['RACK_ENV'] = 'test'

  module RackHeaderHack
    def set_headers(headers)
      browser = page.driver.browser
      def browser.env
        @env.merge(super)
      end
      def browser.env=(env)
        @env = env
      end
      browser.env = headers
    end
  end

  # Capybara.register_driver :selenium do |app|
  #   Capybara::Selenium::Driver.new(app, :browser => :chrome)
  # end

  World(Capybara, Rack::Test::Methods, RackHeaderHack, WorldHelpers, Anticipate)

  require 'rest-assured/config'
  db_opts = { :adapter => 'mysql' }
  RestAssured::Config.build(db_opts)

  require 'rest-assured'
  require 'shoulda-matchers'

  RestAssured::Server.start(db_opts.merge(:port => 9876))

  Before "@api_server" do
    RestAssured::Server.stop
  end
  After "@api_server" do
    RestAssured::Server.start(db_opts.merge(:port => 9876))
  end
end

Spork.each_run do
  require 'rest-assured/application'

  def app
    RestAssured::Application
  end
  Capybara.app = app

  DatabaseCleaner.strategy = :truncation

  Before do
    DatabaseCleaner.start
  end

  Before "@ui" do
    set_headers "HTTP_USER_AGENT" => 'Firefox'
  end

  After do
    sleep 0.1
    DatabaseCleaner.clean

    @t.join if @t.is_a?(Thread)
  end
end

