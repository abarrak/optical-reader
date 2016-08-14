## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require_relative '../app'

module OpticalReaderTest
  class AppTest < Minitest::Test
    include Rack::Test::Methods

    def app
      OpticalReader::App
    end

    def test_static_pages_router
      ['ar', 'en'].each do |l|
        I18n.locale = l
        ['', 'about', 'privacy', 'scan', 'faq', 'apps'].each do |p|
          page_name = p.empty? ? 'home' : p
          get "/#{p}" do
            assert last_response.ok?
            assert last_response.body =~ /#{I18n.t page_name}/i
          end
        end
      end
    end

  end
end
