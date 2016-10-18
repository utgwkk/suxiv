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
    end

    get '/' do
      erb :index
    end
  end
end

