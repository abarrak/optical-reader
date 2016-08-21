require_relative 'base'

module OpticalReader
  class App < Sinatra::Application

    # App filters.
    before do
      headers 'Content-type' => 'text/html; charset=utf-8'
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

      unless verify_recaptcha timeout: 15
        flash.now[:alert] = t 'errors.wrong_captcha'
        return serve_page :scan
      end

      unless v.validate_scan_input
        @errors = v.errors
        return serve_page :scan
      end

      # Store valid file and keep its name for next stages.
      session['document_path'] = save_document params[:document]
      session['language'] = params[:language]
      session['review_me'] = params[:review_me]

      # Go next depending on 'review_me' param.
      if !params[:review_me].nil? && params[:review_me] == 'on'
        redirect to('/review')
      else
        redirect to('/export')
      end
    end

    get '/review' do
      exit_wizard_on_invalid_state

      doc_url, lang = session['document_path'], session['language']
      output = recognize doc_url, lang

      # Transform doc path to full url in dev. In production, it's already done.
      doc_url = File.join(settings.upload_url, doc_url.split('/').last) if settings.development?

      locals = { output: "#{output}", document_url: doc_url }
      serve_page :review, nil, locals
    end

    [self.method(:get), self.method(:post)].each do |http_method|
      http_method.call '/export' do
        unless session['review_me'] == 'on'
          exit_wizard_on_invalid_state

          doc_path, lang = session['document_path'], session['language']
          output = recognize doc_path, lang
        else
          unless Validator.new(params).validate_export_input
            flash[:alert] = t 'errors.export_empty'
            redirect to('/scan')
          end
          output = params[:reviewed_text]
        end

        # generate and store files.
        txt_url, pdf_url = generate_files! output, session['language']
        filename = txt_url.split('/').last.split('.').first

        # clear all session data and serve export.
        serve_page :export, nil, { txt_url: txt_url, pdf_url: pdf_url, filename: filename,
                                   image_url: session['document_path'] }
        session.clear
      end
    end

    # give user the option to delete files manually upon finishing.
    post '/clean' do
      v = Validator.new nil
      pic_path, output_filename = params[:image_url], params[:filename]

      unless pic_path.nil? && output_filename.nil?
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
      serve_page :not_found, :_error
    end

    error do
      if settings.development?
        settings.log.error "(500) Error. \nMessage: #{env['sinatra.error'].message} \
                            \nFull Errpr: \n#{env['sinatra.error'].to_yaml}"
      end
      serve_page :error, :_error
    end

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

    # delete files that have been there for 1 hour.
    Helpers.schedule_for_cleanup
  end
end

# start the server if ruby file executed directly
OpticalReader::App.run! if __FILE__ == $0
