require 'sinatra/base'
require 'tilt/erubis'
require 'erubis'

module Suxiv
  class WebApp < Sinatra::Base
    set :erb, escape_html: true
    set :public_folder, File.expand_path('../static', __FILE__)

    helpers do
      def config
        @config ||= {
          db: {
            path: "/home/utgw/reimuchan/image.db"
          }
        }
      end

      def db
        return Thread.current[:suxiv_db] if Thread.current[:suxiv_db]
        client = SQLite3::Database.new config[:db][:path], results_as_hash: true
        Thread.current[:suxiv_db] = client
        client
      end
    end

    get '/' do
      erb :index
    end
  end
end

