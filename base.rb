# encoding: utf-8
## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

require 'sinatra/base'
require 'sinatra/respond_with'
require 'sinatra/json'
require 'sinatra/reloader'
require 'encrypted_cookie'
require 'rack/protection'
require 'rack-flash'
require 'logger'
require 'securerandom'
require 'json'
require 'yaml'
require 'tempfile'
require 'mail'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'rufus/scheduler'
require 'rtesseract'
require 'mini_magick'
require 'prawn'
require 'arabic-letter-connector'
require 'fastimage'
require 'recaptcha'
require 'dotenv'
require 'aws-sdk'
require './service/ocr'
require './service/validator'
require './helpers'

module OpticalReader
  class App < Sinatra::Application
    # load environment variables.
    Dotenv.load

    # App middleware.
    use Rack::Session::EncryptedCookie, secret: ENV['COOKIE_SECRET']
    use Rack::Protection::AuthenticityToken
    use Rack::Flash

    # request types.
    respond_to :html, :json

    configure do
      # general settings
      set :root, File.dirname(__FILE__)
      set :website_link, 'http://opticalreader.net'

      # layout and static content.
      set :upload_path, File.join(settings.public_folder, 'ocr-uploads')
      set :output_path, File.join(settings.public_folder, 'ocr-output')
      set :upload_url, File.join('', 'ocr-uploads')
      set :output_url, File.join('', 'ocr-output')

      set :static_cache_control, true

      # i18n setup.
      I18n::Backend::Simple.send :include, I18n::Backend::Fallbacks
      I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
      I18n.backend.load_translations

      # mail settings.
      set :mail_username, ENV['MAIL_USERNAME']
      set :mail_password, ENV['MAIL_PASSWORD']
      set :mail_receiver, ENV['MAIL_RECEIVER']
      set :mail_address, 'smtp.gmail.com'
      set :mail_domain, 'mail.google.com'
      set :mail_port, 587

      # S3 bucket
      set :s3_region, ENV['AWS_REGION']
      set :s3_bucket_name, ENV['AWS_BUCKET_NAME']
    end

    # App settings.
    configure :development do
      register Sinatra::Reloader
      # set custom logger.
      enable :logging
      log_path = File.join settings.root, "logs", "development.log"
      set :log, Logger.new(File.new log_path, 'a+', sync: true)
    end

    # reCaptcha settings.
    Recaptcha.configure do |config|
      config.public_key  = ENV['RECAPTCHA_PUBLIC_KEY']
      config.private_key = ENV['RECAPTCHA_PRIVATE_KEY']
    end

    configure :production do
      set :server, :puma
      set :raise_errors, false
      set :show_exceptions, false
    end

  end
end
