module OpticalReader
  module Helpers

    def page_title title = nil
      base = I18n.t :base_title
      title.nil? ? base.to_s : "#{I18n.t title} | #{base}"
    end

    # setting automatic escape breaks partials by repeating escaping.
    # escape them manually or on asingle template basis.
    def h text
      Rack::Utils.escape_html text
    end

    # helper for serving static pages.
    def serve_page name, layout = nil, locals = nil
      yield if block_given?

      @title = page_title name.to_sym

      respond_to do |f|
        f.html { erb name.to_sym, layout: layout || :_layout, locals: locals || {} }
        f.json { json title: @title, body: t("static_content.#{name.to_s}.body") }
      end
    end

    def csrf_name
      'authenticity_token'
    end

    def csrf_token
      session[:csrf]
    end

    def unique_name
      SecureRandom.urlsafe_base64
    end

    def t key, options = {}
      I18n.t key, options
    end

    def ar?
      I18n.locale == :ar
    end

    def sharify title
      title.sub '|', t('on_word')
    end

    def exit_wizard_on_invalid_state
      unless OpticalReader::Service::Validator.new(session).validate_wizard_session
          flash[:alert] = t 'error.apology_505'
          redirect '/scan'
      end
    end

    def s3_bucket
      Aws::S3::Resource.new(region: settings.s3_region).bucket settings.s3_bucket_name
    end

    def recognize doc_path, lang = :eng, format = :txt
      doc_path = MiniMagick::Image.open doc_path if settings.production?
      Service::OCR.new(doc_path, lang).recognize
    end

    # Upload image to S3 or filesystem according to environment and return its link or path.
    def save_document doc
      filename = "#{unique_name}#{File.extname(doc[:filename])}"
      file = doc[:tempfile]
      if settings.production?
        obj = s3_bucket.object filename
        obj.upload_file file
        obj.public_url
      else
        path = File.join settings.upload_path, filename
        File.open path, "wb" do |f|
          f.write file.read
        end
        # return relative path for dev environment.
        path
      end
    end

    def generate_files! content, language
      name = unique_name
      txt_url = generate_txt_file "#{name}.txt", content
      pdf_url = generate_pdf_file "#{name}.pdf", content, language
      [txt_url, pdf_url]
    end

    # Create text version and return its link.
    def generate_txt_file name, content
      if settings.production?
        txt_obj = s3_bucket.object name
        file = Tempfile.new name
        begin
          file.write content
          txt_obj.upload_file file
        ensure
          file.close
          file.unlink
        end
        txt_obj.public_url
      else
        path = File.join settings.output_path, name
        File.open(path, 'w') { |f| f.write content }
        File.join settings.output_url, name
      end
    end

    # Create pdf version and return its link.
    def generate_pdf_file name, content, language
      if settings.production?
        pdf_obj = s3_bucket.object name
        tmp_file = Tempfile.new name
        begin
          pdf_generator.call tmp_file.path, content, language
          pdf_obj.upload_file tmp_file
        ensure
          tmp_file.close
          tmp_file.unlink
        end
        pdf_obj.public_url
      else
        path = File.join settings.output_path, name
        pdf_generator.call path, content, language
        File.join settings.output_url, name
      end
    end

    def pdf_generator
      lambda do |path, content, lang|
        # content, lang = content, lang
        font_file = "#{settings.public_folder}/fonts/Arial.ttf"
        Prawn::Document.generate path do
          content.encode! Encoding.find('UTF-8'), { invalid: :replace, undef: :replace, replace: '' }
          if lang == 'ara'
            text_direction :rtl
            content = content.connect_arabic_letters.force_encoding("UTF-8")
          end
          font font_file
          text content
        end
      end
    end

    # Cleanup remaining files after processing. Intended to be used in production,
    # but it turns out in aws, I should use "Amazon S3 – Object Expiration" instead.
    def self.schedule_for_cleanup
      if App.settings.development?
        # since ENV=dev, keep it to files with 3 min age & run every 5 min.
        Rufus::Scheduler.new.every '5m' do
          puts "cleaning task is running .."
          delete_files! 3
        end
      end
    end

    # Delete each file that exceeds age_in_minutes since creation.
    def self.delete_files! age_in_minutes
      self.iterate_delete App.settings.upload_path, age_in_minutes
      self.iterate_delete App.settings.output_path, age_in_minutes
    end

    def self.iterate_delete dir_path, age_in_minutes
      Dir.foreach dir_path do |file|
        next if file == '.' or file == '..' or file == '.DS_Store'

        full_path = "#{dir_path}/#{file}"
        File.unlink "#{full_path}" if Time.now - File.ctime(full_path) > (1 * 60 * age_in_minutes)
      end
    end

    # Delete triggered by user.
    def delete_one! img_path, ocr_filename
      if settings.development?
        File.unlink img_path
        File.unlink "#{settings.output_path}/#{ocr_filename}.pdf"
        File.unlink "#{settings.output_path}/#{ocr_filename}.txt"
      else
        all = [
          { key: img_path.split('/').last },
          { key: "#{ocr_filename}.pdf" },
          { key: "#{ocr_filename}.txt" }]

        s3_bucket.delete_objects delete: { objects: all }
      end
    end

    def setup_mail
      user, password, address, domain, port = settings.mail_username, settings.mail_password,
                                              settings.mail_address, settings.mail_domain,
                                              settings.mail_port
      Mail.defaults do
        delivery_method :smtp, {
          :address              => address,
          :port                 => port,
          :user_name            => user,
          :password             => password,
          :authentication       => :plain,
          :enable_starttls_auto => true,
          :domain               => domain,
          :charset              => 'utf-8'
        }
      end
    end

    def to_contact_type numeric_type
      types = { 1 => t('static_content.contact.question'),
                2 => t('static_content.contact.suggestion'),
                3 => t('static_content.contact.complaint'),
                4 => t('Other') }
      types[numeric_type.to_i]
    end

    def thank_mail sender_name, sender_email, subject
      setup_mail

      locals = { heading: t('mail.notification'), name: sender_name, subject: subject }
      html_body, txt_body = fetch_mail_versions :thank, locals

      mail = Mail.new do
        to        sender_email
        text_part { body txt_body }
        html_part { content_type 'text/html; charset=UTF-8'; body html_body }
      end
      mail.from    = settings.mail_username
      mail.subject = t('mail.contact_email_subject')
      mail.deliver
    end

    def contact_mail sender_name, sender_email, subject, type, message
      setup_mail

      locals = { heading: t('mail.notification'), name: sender_name, email: sender_email,
                 subject: subject, type: type, message: message }
      html_body, txt_body = fetch_mail_versions :contact, locals

      mail = Mail.new do
        text_part { body txt_body }
        html_part { content_type 'text/html; charset=UTF-8'; body html_body }
      end
      mail.from     = settings.mail_username
      mail.to       = settings.mail_receiver
      mail.subject  = t('mail.contact_email_subject')
      mail.deliver
    end

    def fetch_mail_versions name, locals
      html = erb :"mail/#{name.to_s}.html", layout: :'mail/_layout', escape_html: true,
                 locals: locals, layout_options: { escape_html: false }
      text = erb :"mail/#{name.to_s}.txt", layout: false, escape_html: true, locals: locals

      return html, text
    end

  end
end
