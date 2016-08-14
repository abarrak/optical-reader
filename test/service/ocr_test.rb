## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

require 'minitest/autorun'
require 'minitest/pride'
require_relative '../../service/ocr'

module OpticalReaderTest
  module ServiceTest

    class OCRTest < Minitest::Test
      include OpticalReader::Service

      def setup
        @ocr = OCR.new "test-sample.png", :en
      end

      def test_recognize_result
      end

      def test_recognize_english
        @ocr.doc_path = "test-en.png"
        @ocr.lang = :en
      end

      def test_recognize_arabic
        @ocr.doc_path = "test-ar.png"
        @ocr.lang = :ar
      end
    end

  end
end
