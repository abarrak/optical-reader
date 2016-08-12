## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require '../app'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_static_pages_router
    get '/'
    assert last_response.ok?
  end
end
