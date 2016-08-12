## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

require_relative 'base'

module OpticalReader
  class App < Sinatra::Application
    include Recaptcha::ClientHelper
    include Recaptcha::Verify
    include Service

    # App filters.
    before do
      @logger = settings.log if settings.development?
      @errors = {}
      # ensure csrf token.
      unless request.xhr?
         session[:csrf] ||= Rack::Protection::Base.new(self).random_string
      end
    end

    before '/:locale/*' do
      locales = ['ar', 'en'].freeze
      I18n.locale = locales.include?(params[:locale]) ? params[:locale].to_sym : :en
      request.path_info = '/' + params[:splat][0]
    end

    # App routes and handlers.
    ['', 'about', 'privacy', 'scan', 'faq', 'apps'].each do |p|
      get "/#{p}" do
          serve_page (p.empty? ? :home : p.to_sym)
      end
    end

    get '/contact' do
      respond_to do |f|
        f.html { @title = page_title :contact; erb :contact, layout: :_layout }
        f.json { json :title => t('contact'), "#{csrf_name}".to_sym => csrf_token }
      end
    end

    post '/contact' do
      @title = page_title :contact
      v = Validator.new params

      unless v.validate_contact_input
        @errors = v.errors
        respond_to do |f|
          f.html { erb :contact, layout: :_layout }
          f.json { json title: t('contact'), errors: @errors }
        end

      else
        n, e, s, t, m = params[:name], params[:email], params[:subject],
                        to_contact_type(params[:type]), params[:message]

        contact_mail n, e, s, t, m
        thank_mail n, e, s

        sent_notice = "#{t 'mail.thank_for_contact', name: n }"
        respond_to do |f|
          f.html { flash[:success] = sent_notice; redirect to('/sent') }
          f.json { json  title: t('sent'), body: "#{sent_notice}\n#{t 'mail.tell_for_contact'}" }
        end
      end
    end

    get '/sent' do
      redirect to('/') if flash[:success].nil? || flash[:success].empty?
      serve_page :sent
    end

    post '/scan' do
      v = Validator.new params

      unless v.validate_scan_input
        @errors = v.errors
        return serve_page :scan
      end

      unless verify_recaptcha timeout: 15
        flash.now[:alert] = t 'errors.wrong_captcha'
        return serve_page :scan
      end

      # store valid file and keep its name for next stages.
      session['document_path'] = save_document params[:document]
      session['language'] = params[:language]
      session['review_me'] = params[:review_me]

      # go next depending on 'review_me' param.
      if !params[:review_me].nil? && params[:review_me] == 'on'
        redirect to('/review'), 307
      else
        redirect to('/export'), 307
      end
    end

    post '/review' do
      doc_url, lang = session['document_path'], session['language']
      output = recognize doc_url, lang

      # transform doc path to full url in dev. In production, it's already done.
      doc_url = File.join(settings.upload_url, doc_url.split('/').last) if settings.development?

      locals = { output: "#{output}", document_url: doc_url }
      serve_page :review, nil, locals
    end

    post '/export' do
      if session['review_me'] != 'on'
        if session['document_path'].nil? || session['language'].nil?
          flash[:alert] = t 'error.apology_505'
          redirect '/scan'
        end
        doc_path, lang = session['document_path'], session['language']
        output = recognize doc_path, lang
      else
        unless Validator.new(params).validate_export_input
          flash[:alert] = t 'errors.export_empty'
          redirect '/scan'
        end
        output = params[:reviewed_text]
      end

      # generate and store files.
      txt_url, pdf_url = generate_files! output, session['language']
      filename = txt_url.split('/').last.split('.').first

      serve_page :export, nil, { txt_url: txt_url, pdf_url: pdf_url, filename: filename }
    end

    # give user the option to delete files manually upon finishing.
    post '/clean' do
      v = Validator.new nil
      pic_path, output_filename = session['document_path'], params[:filename]

      unless pic_path.nil? || output_filename.nil?
        delete_one! pic_path, output_filename
        flash[:success] = t 'static_content.wizard.files_deleted'
        redirect to('scan')
      else
        flash[:alert] = t 'errors.apology_505'
        redirect to('scan')
      end
    end

    # Error handlers.
    not_found do
      if settings.development?
        @logger.warn "(404) Not Found. \nRequest dump: \n#{request.inspect.to_yaml}"
      end
      serve_page :not_found, :_error
    end

    error do
      if settings.development?
        @logger.warn "(500) Something went wrong. \nMessage: #{env['sinatra.error'].message} \
                      \nFull Errpr: \n#{env['sinatra.error'].to_yaml}"
      end
      serve_page :error, :_error
    end

    # api (non-get) routes.
    # 'serve_page' covers get routes restfully.


    # Mail preview in development only.
    get '/preview/:mail.:format' do
      not_found unless settings.development?

      m, f = "#{params[:mail]}", "#{params[:format]}"
      layout = f == 'txt' ? false : :"mail/_layout"
      content_type "text/#{f == 'txt' ? 'plain' : 'html'}"
      erb :"mail/#{m}.#{f}", layout: layout, escape_html: true,
          layout_options: { escape_html: false }, locals: { heading: t('mail.preview') }
    end

    # App helpers.
    helpers OpticalReader::Helpers

    # override sinatra uri for i18n aware url genreation.
    def uri addr = nil, absolute = true, add_script_name = true
      return addr if addr =~ /\A[a-z][a-z0-9\+\.\-]*:/i
      uri = [host = String.new]
      if absolute
        host << "http#{'s' if request.secure?}://"
        if request.forwarded? or request.port != (request.secure? ? 443 : 80)
          host << request.host_with_port
        else
          host << request.host
        end
      end
      uri << request.script_name.to_s if add_script_name
      uri << I18n.locale.to_s
      uri << (addr ? addr : request.path_info).to_s
      File.join uri
    end

    # :to to alias the new implementation. url not 'for agnostic stuff. e.g.: public'
    alias to uri

    # delete files that have been there for 1 hour.
    Helpers.schedule_for_cleanup
  end
end

# start the server if ruby file executed directly
OpticalReader::App.run! if __FILE__ == $0
