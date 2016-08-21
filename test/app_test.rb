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
      @lang = ['eng', 'ara'].sample
      @acceptable = {
        'eng' => File.expand_path("test-images/sample-eng.png", File.dirname(__FILE__)),
        'ara' => File.expand_path("test-images/sample-ara.png", File.dirname(__FILE__))
      }
      @excceding  = File.expand_path "test-images/large.png", File.dirname(__FILE__)

      # tests should pass for each locales.
      I18n.locale = ['ar', 'en'].sample
    end

    def teardown
      OpticalReader::Helpers.delete_files! 1
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

      post '/scan', language: @lang
      assert_equal errors_count(last_response), 1

      post '/scan', document: UploadedFile.new(@acceptable[@lang], "image/png")
      assert_equal errors_count(last_response), 1
    end

    def test_scan_accepts_proper_submission
      post '/scan', language: @lang,
                    document: UploadedFile.new(@acceptable[@lang], "image/png")
      assert_equal errors_count(last_response), 0
      assert last_response.status == 302
    end

    def test_scan_redirect_to_review
      post '/scan', language: @lang,
                    document: UploadedFile.new(@acceptable[@lang], "image/png"),
                    review_me: 'on'
      assert last_response.status == 302
      follow_redirect!
      assert last_response.body.include? I18n.t 'static_content.wizard.review.explaination'
    end

    #  && sinatra.route && rack.session
    def test_scan_redirect_to_export
      post '/scan', language: @lang,
                    document: UploadedFile.new(@acceptable[@lang], "image/png"),
                    review_me: [nil, 'off', '', 'whatever'].sample
      assert last_response.status == 302
      follow_redirect!

      assert last_response.body.include? I18n.t 'static_content.wizard.export.explaination'
    end

    def test_wizard_prevents_improper_transitions
      # review cannot be visited initially or with corrupt session.
      get '/review'
      assert_redirected_to_scan

      # export cannot be visited initially or with corrupt session.
      get '/export'
      assert_redirected_to_scan

      # last_request.env['rack.session'].clear
      # valid_post_to_scan :export
      # assert_redirected_to_scan
    end

    def test_review_shows_ocr_output_and_document_image
      valid_post_to_scan :review
      assert last_response.status == 302
      follow_redirect!
      assert_equal last_request.env['sinatra.route'], 'GET /review'

      doc_url = last_request.env['rack.session']['document_path']
      lang    = last_request.env['rack.session']['language']
      assert last_response.body.include? doc_url.split('/').last
      assert last_response.body.include? OpticalReader::Service::OCR.new(doc_url, lang).recognize
    end

    def test_exports_rejects_in_case_of_review_me_and_no_reviewed_text_is_give
      valid_post_to_scan :review
      assert last_response.status == 302
      follow_redirect!
      assert_equal last_request.env['sinatra.route'], 'GET /review'
      last_request.env['sinatra.session']
      get '/export', { reviewed_text: "\n   " }
      assert_redirected_to_scan
    end

    def test_exports_scans_and_gives_output_files_in_valid_state
      valid_post_to_scan :export
      assert last_response.status == 302
      follow_redirect!
      assert_equal last_request.env['sinatra.route'], 'GET /export'
      assert last_response.body.include? '.txt'
      assert last_response.body.include? '.pdf'
    end

    def test_clean_functionality
      valid_post_to_scan :export
      assert last_response.status == 302
      follow_redirect!
      assert_equal last_request.env['sinatra.route'], 'GET /export'

      grap_link = lambda do |respones_body, attr_name|
        tag = /[<]input type="hidden" name="#{attr_name}" value="(?<holder>.+)"/
        m = respones_body.match tag
        m[:holder]
      end
      file_link = grap_link.call(last_response.body, 'filename')
      img_link = grap_link.call(last_response.body, 'image_url')

      post '/clean', { filename: file_link, image_url: img_link }
      assert_equal last_response.status, 302
      follow_redirect!
      assert_equal last_request.env['sinatra.route'], 'GET /scan'
      assert !last_request.env['x-rack.flash'][:success].empty?
    end

    def test_contact_functionality
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
        assert_equal last_request.env['sinatra.route'], 'GET /scan'
        assert last_response.body.include? I18n.t 'static_content.wizard.scan_step_1'
        assert !last_request.env['x-rack.flash'][:alert].empty?
      end

      def valid_post_to_scan next_route
        review_me = next_route == :review ? 'on' : [nil, 'off', '', 'whatever'].sample
        post '/scan', { language: @lang,
                        document: UploadedFile.new(@acceptable[@lang], "image/png"),
                        review_me: review_me }
      end
  end
end
