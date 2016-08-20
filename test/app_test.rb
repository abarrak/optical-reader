require_relative 'test_helper'

module OpticalReaderTest
  class AppTest < Minitest::Test
    include Rack::Test
    include Rack::Test::Methods
    include OpticalReaderTest::Helper

    def app
      OpticalReader::App
    end

    def setup
      @acceptable = File.expand_path "test-images/sample-eng.png", File.dirname(__FILE__)
      @excceding  = File.expand_path "test-images/large.png", File.dirname(__FILE__)

      # tests should pass for each locales.
      ['ar', 'en'].each { |l| I18n.locale = l }
    end

    def teardown
    end

    def test_static_pages_router
      ['', 'about', 'privacy', 'scan', 'faq', 'apps'].each do |p|
        page_name = p.empty? ? 'home' : p
        get "/#{p}"
        assert last_response.ok?
        assert last_response.body =~ /#{I18n.t page_name}/i
      end
    end

    def test_scan_rejects_improper_submission
      post '/scan'
      assert_equal errors_count(last_response), 2

      post '/scan', language: :foo
      assert_equal errors_count(last_response), 2

      post '/scan', document: UploadedFile.new(@excceding, "image/png")
      assert_equal errors_count(last_response), 2

      post '/scan', language: [:eng, :ara].sample
      assert_equal errors_count(last_response), 1

      post '/scan', document: UploadedFile.new(@acceptable, "image/png")
      assert_equal errors_count(last_response), 1
    end

    def test_scan_accepts_proper_submission
      post '/scan', language: [:eng, :ara].sample,
                    document: UploadedFile.new(@acceptable, "image/png")
      assert_equal errors_count(last_response), 0
      assert last_response.status == 302
    end

    def test_scan_redirect_to_review
      post '/scan', language: [:eng, :ara].sample,
                    document: UploadedFile.new(@acceptable, "image/png"),
                    review_me: 'on'
      assert last_response.status == 302
      follow_redirect!
      assert last_response.body.include? I18n.t 'static_content.wizard.review.explaination'
    end

    def test_scan_redirect_to_export
      post '/scan', language: [:eng, :ara].sample,
                    document: UploadedFile.new(@acceptable, "image/png"),
                    review_me: [nil, 'off', '', 'whatever'].sample
      assert last_response.status == 302
      follow_redirect!
      assert last_response.body.include? I18n.t 'static_content.wizard.export.explaination'
    end

    def test_wizard_prevents_improper_transitions
      # review cannot be visited initially.
      get '/review'
      assert_redirected_to_scan

      # export cannot be visited initially or with corrupt session.
      get '/export'
      assert_redirected_to_scan
    end

    def test_contact_
    end

    def test_contact_
    end

    def test_404_shows_up_when_needed
      get ['/artist', '/love', '/admin/secret'].sample
      assert_equal last_response.status, 404
      assert last_response.body.include? I18n.t 'not_found'
      assert last_response.body.include? I18n.t 'errors.apology_404'
    end

    private

      def assert_redirected_to_scan
        assert last_response.status == 302
        follow_redirect!
        assert last_response.body.include? I18n.t 'static_content.wizard.scan_step_1'
      end
  end
end
