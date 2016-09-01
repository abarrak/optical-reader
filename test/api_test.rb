require_relative 'test_helper'

module OpticalReaderTest
  class ApiTest < Minitest::Test
    include Rack::Test
    include Rack::Test::Methods

    def app
      OpticalReader::Api
    end

    def setup
      @api_prefix = "/api/v1"
      # tests should pass for each locales.
      @lang = ['eng', 'ara'].sample
      I18n.locale = ['ar', 'en'].sample
    end

    def test_should_reject_without_access_token
      ['', 'about', 'privacy', 'scan', 'faq', 'apps'].each do |p|
        get "/#{p}"
        assert !last_response.ok?
        assert_equal last_response.status, 403
        assert last_response.body =~ /#{I18n.t(:acceess_denied)}/
      end
    end

  end
end
