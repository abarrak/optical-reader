## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

module OpticalReader
  module Service

    class OCR
      attr_accessor :doc_path
      attr_accessor :lang
      attr_reader :text

      def initialize doc_path, lang
        @doc_path = doc_path
        @lang = lang

        RTesseract.configure do |config|
          config.processor = "mini_magick"
        end
      end

      def recognize
        (RTesseract.new @doc_path, lang: @lang).to_s
      end

      def self.langs
        ['ara', 'eng'].freeze
      end
    end

  end
end
