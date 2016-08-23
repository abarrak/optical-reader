# encoding: UTF-8
# 😁
require_relative 'base'
require_relative 'override'

module OpticalReader
  class Api < Base
    # right now, it's a internal api with one fixed access token, meant for our appps.
    authentication_token = ENV['API_AUTH_TOKEN'].freeze

    # Api filters.
    before do
      # before any api request, verify access token.
      raise AccessDeniedError unless params[:auth_token] == authentication_token
    end

    after do
      headers 'Content-type' => 'application/json; charset=utf-8'
    end

    # Api routes and handlers
    ['about', 'privacy', 'scan', 'faq', 'apps'].each do |p|
      get "/#{p}" do
          serve_api_content p.to_sym
      end
    end

    post '/contact' do
      v = Validator.new params
      unless v.validate_contact_input
        @errors = v.errors
        status 400
        return json title: t('contact'), errors: @errors
      else
        n, e, s, t, m = params[:name], params[:email], params[:subject],
                        to_contact_type(params[:type]), params[:message]
        contact_mail n, e, s, t, m
        thank_mail n, e, s
        sent_notice = "#{t 'mail.thank_for_contact', name: n}\n#{t 'mail.tell_for_contact'}"
        json title: t('sent'), body: "#{sent_notice}"
      end
    end

    post '/scan' do
      v = Validator.new params
      unless v.validate_scan_input
        @errors = v.errors
        status 400
        return json title: t('scan'), errors: @errors
      end

      doc_url   = save_document params[:document]
      lang      = params[:language]
      review_me = params[:review_me]
      output = recognize doc_url, lang

      if !review_me.nil? && review_me == 'on'
        doc_url = File.join(settings.upload_url, doc_url.split('/').last) if settings.development?
        json title: t('review'), output: output, language: lang, image_url: doc_url
      else
        txt_url, pdf_url = generate_files! output, lang
        json title: t('export'), output: output, language: lang, txt_url: txt_url, pdf_url: pdf_url
     end
    end

    post '/export' do
      v = Validator.new(params)
      # FixMe: refactor export validation & language choice.
      if !v.validate_export_input || v.send(:blank?, params[:language])
        status 400
        return json title: t('export'), error: t('errors.export_empty')
      end
      output, lang = params[:reviewed_text], params[:language]

      txt_url, pdf_url = generate_files! output, lang

      json title: t('export'), output: output, language: lang, txt_url: txt_url, pdf_url: pdf_url
    end

    post '/clean' do
      unless Validator.new(params).validate_clean_input
        status 400
        return json title: t('clean'), error: t('errors.clean_empty')
      else
        delete_one! params[:image_url], params[:filename]
        return json title: t('clean'), body: t('static_content.wizard.files_deleted')
      end
    end

    not_found do
      serve_api_content :not_found
    end

    error do
      serve_api_content :error
    end

    error OpticalReader::AccessDeniedError do
      status 403
      serve_api_content :acceess_denied
    end
  end
end

# start the server if ruby file executed directly
OpticalReader::Api.run! if __FILE__ == $0
