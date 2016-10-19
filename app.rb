require 'sinatra/base'
require 'sinatra/partial'
require 'sqlite3'
require 'tilt/erubis'
require 'erubis'

module Suxiv
  class WebApp < Sinatra::Base
    register Sinatra::Partial

    if ENV["USE_LINEPROF"]
      require 'rack-lineprof'
      use Rack::Lineprof, profile: 'app.rb'
    end

    set :erb, escape_html: true
    set :partial_template_engine, :erb
    set :public_folder, File.expand_path('../static', __FILE__)

    helpers do
      def config
        @config ||= {
          db: {
            path: "/home/utgw/reimuchan/image.db"
          },
          image: {
            full: "/home/utgw/private_html/imgs/",
            thumbnail: "/home/utgw/private_html/thumbnails/"
          }
        }
      end

      def db
        return Thread.current[:suxiv_db] if Thread.current[:suxiv_db]
        client = SQLite3::Database.new config[:db][:path], results_as_hash: true
        Thread.current[:suxiv_db] = client
        client
      end

      def is_valid_tag? tag
        !tag.empty? && tag.size < 32
      end

      def image_path(filename, mode = :full)
        File.join(config[:image][mode], filename)
      end
    end

    get '/' do
      recent_images = db.execute("SELECT SUBSTR(filename, LENGTH('#{config[:image][:full]}') + 1) AS filename FROM images ORDER BY created_at DESC LIMIT 20")

      locals = {
        recent_images: recent_images
      }

      erb :index, locals: locals
    end

    get '/images/all' do
      result = []

      page = unless params["page"].nil? then params["page"].to_i else 0 end
      offset = page * 20

      query = <<SQL
SELECT SUBSTR(filename, LENGTH('#{config[:image][:full]}') + 1) AS filename FROM images
GROUP BY filename
ORDER BY created_at DESC
LIMIT 20
OFFSET ?
SQL
      result = db.execute(query, [offset])

      erb :all_images, locals: {images: result, page: page}
    end

    get '/images/:image_path' do
      content_type 'image/jpeg'
      if params['thumbnail']
        File.open(image_path(params['image_path'], :thumbnail), 'rb').read
      else
        File.open(image_path(params['image_path']), 'rb').read
      end
    end

    get '/images/detail/:image_path' do
      data = db.execute("SELECT SUBSTR(filename, LENGTH('#{config[:image][:full]}') + 1) AS filename, keyword, status_id_str FROM images WHERE filename = ?", [image_path(params["image_path"])]).first

      status_id_str = data["status_id_str"]

      tags = db.execute("SELECT content, COUNT(*) AS num FROM tags WHERE status_id_str = ? GROUP BY content ORDER BY num DESC", [status_id_str])

      erb :detail, locals: {data: data, tags: tags}
    end

    get '/tags' do
      tags = db.execute("SELECT COUNT(*) AS num, content FROM tags GROUP BY content ORDER BY num DESC")

      erb :tags, locals: {tags: tags}
    end

    post '/tags/:image_path' do
      tag = params["content"] || ""

      unless is_valid_tag? tag
        halt 400
      end

      status_id_str = db.execute("SELECT * FROM images WHERE filename = ?", [image_path(params['image_path'])]).first["status_id_str"]

      if db.execute("SELECT COUNT(*) FROM tags WHERE content = ? AND status_id_str = ?", [tag, status_id_str]).first[0] > 0
        status 304
        redirect "/images/detail/#{params["image_path"]}"
      end

      if db.execute("SELECT COUNT(*) FROM tags WHERE status_id_str = ?", [status_id_str]).first[0] >= 10
        halt 403
      end

      db.execute("INSERT INTO tags (content, status_id_str) VALUES (?, ?)", [tag, status_id_str])
      redirect "/images/detail/#{params["image_path"]}"
    end

    post '/tags/delete/:image_path' do
      tag = params["content"] || ""

      status_id_str = db.execute("SELECT status_id_str FROM images WHERE filename = ?", [image_path(params['image_path'])]).first["status_id_str"]

      db.execute("DELETE FROM tags WHERE status_id_str = ? AND content = ?", [status_id_str, tag])
      redirect "/images/detail/#{params["image_path"]}"
    end

    get '/search' do
      result = []

      page = unless params["page"].nil? then params["page"].to_i else 0 end
      offset = page * 20

      if params["q"].nil? || params["q"].empty?
        halt 400
      end

      tags = params["q"].split

      if params["mode"] == "tag"
        query = <<SQL
SELECT SUBSTR(images.filename, LENGTH('#{config[:image][:full]}') + 1) AS filename FROM images, tags
WHERE images.status_id_str = tags.status_id_str
AND (tags.content IN (#{(['?'] * tags.size).join ', '}))
GROUP BY images.filename
ORDER BY created_at DESC
LIMIT 20
OFFSET ?
SQL
        result = db.execute(query, [*tags, offset])
      else
        query = <<SQL
SELECT SUBSTR(filename, LENGTH('#{config[:image][:full]}') + 1) AS filename FROM images
WHERE keyword LIKE ?
GROUP BY filename
ORDER BY created_at DESC
LIMIT 20
OFFSET ?
SQL
        result = db.execute(query, ["%#{params["q"]}%", offset])
      end

      erb :search, locals: {images: result, page: page}
    end
  end
end

