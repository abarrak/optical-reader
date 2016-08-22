# encoding: UTF-8
# 😁
require_relative 'base'

module OpticalReader
  class Api < Sinatra::Application

    before '/:locale/*' do
      locales = ['ar', 'en'].freeze
      I18n.locale = locales.include?(params[:locale]) ? params[:locale].to_sym : :en
      request.path_info = '/' + params[:splat][0]
    end

    ['about', 'privacy', 'scan', 'faq', 'apps'].each do |p|
      get "/#{p}" do
          serve_api_content p.to_sym
      end
    end

    post '/contact' do
      v = Validator.new params
      unless v.validate_contact_input
        @errors = v.errors
        json title: t('contact'), errors: @errors
      else
        n, e, s, t, m = params[:name], params[:email], params[:subject],
                        to_contact_type(params[:type]), params[:message]
        contact_mail n, e, s, t, m
        thank_mail n, e, s
        sent_notice = "#{t 'mail.thank_for_contact', name: n}\n#{t 'mail.tell_for_contact'}"
        json title: t('sent'), body: "#{sent_notice}"
      end
    end

    helpers OpticalReader::Helpers

  end
end

# start the server if ruby file executed directly
OpticalReader::Api.run! if __FILE__ == $0
