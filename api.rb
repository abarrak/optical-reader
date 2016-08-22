# encoding: UTF-8
# 😁
require_relative 'base'
require_relative 'override'

module OpticalReader
  class Api < Base

    # right now, it's a internal api with one fixed access token, meant for our appps.
    authentication_token = ENV['API_AUTH_TOKEN'].freeze

    # before any api request, verify access token.
    before do
      raise AccessDeniedError unless params[:auth_token] == authentication_token
    end

    after do
      headers 'Content-type' => 'application/json; charset=utf-8'
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
