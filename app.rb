require 'sinatra/base'
require 'sqlite3'
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
          },
          image: {
            base_path: "/home/utgw/private_html/imgs/"
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
      recent_images = db.execute("SELECT filename FROM images ORDER BY created_at DESC LIMIT 10").map { |img|
        File.basename(img["filename"])
      }

      locals = {
        recent_images: recent_images
      }

      erb :index, locals: locals
    end

    get '/images/:image_path' do
      content_type 'image/jpeg'
      File.open(File.join(config[:image][:base_path], params['image_path']), 'rb').read
    end
  end
end

