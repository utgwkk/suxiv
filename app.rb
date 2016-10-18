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
            base_path: "/home/utgw/private_html/imgs/",
            thumbnail_path: "/home/utgw/private_html/thumbnails/"
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
      if params['thumbnail']
        File.open(File.join(config[:image][:thumbnail_path], params['image_path']), 'rb').read
      else
        File.open(File.join(config[:image][:base_path], params['image_path']), 'rb').read
      end
    end

    get '/images/detail/:image_path' do
      data = db.execute("SELECT * FROM images WHERE filename LIKE ?", ["%" + params["image_path"]]).map {|img|
        img["filename"] = File.basename(img["filename"])
        img
      }.first

      status_id_str = data["status_id_str"]

      tags = db.execute("SELECT content FROM tags WHERE status_id_str = ?", [status_id_str]).map {|tag|
        tag["content"]
      }

      erb :detail, locals: {data: data, tags: tags}
    end

    get '/tags' do
      tags = db.execute("SELECT COUNT(*) AS num, content FROM tags GROUP BY content")

      erb :tags, locals: {tags: tags}
    end
  end
end

