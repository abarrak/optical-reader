# encoding: UTF-8
# 😁
module OpticalReader
  module Service
    class OCR
      attr_accessor :doc_path
      attr_accessor :lang
      attr_reader :text

      def initialize doc_path, lang
        @doc_path = doc_path
        @lang = lang
        validate_params
        RTesseract.configure do |config|
          config.processor = "mini_magick"
        end
      end

      def validate_params
        raise ArgumentError.new 'Please supply a path for the document image.' if @doc_path.nil?
        raise ArgumentError.new 'Please supply a lang for the document image.' if @lang.nil?
        raise ArgumentError.new 'Language is not recognizable.' unless OCR.langs.include? @lang.to_s
      end

      def recognize
        validate_params
        RTesseract.new(@doc_path, lang: @lang).to_s
      end

      def self.langs
        ['ara', 'eng'].freeze
      end
    end
  end
end
