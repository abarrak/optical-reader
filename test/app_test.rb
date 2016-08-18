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

    def test_scan_rejects_missing_recaptca
    end

    def test_scan_rejects_invalid_recaptca
    end

    def test_scan_rejects_improper_submission
    end

    def test_scan_accepts_proper_submission
    end

  end
end
