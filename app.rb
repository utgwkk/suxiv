require 'sinatra/base'
require 'tilt/erubis'
require 'erubis'

module Suxiv
  class WebApp < Sinatra::Base
    set :erb, escape_html: true

    get '/' do
      'Hello, world!'
    end
  end
end

