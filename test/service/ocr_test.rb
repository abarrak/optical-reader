require_relative '../test_helper'

module OpticalReaderTest
  module ServiceTest

    class OCRTest < Minitest::Test
      include OpticalReader::Service

      def setup
        @eng_image = File.expand_path "../test-images/sample-eng.png", File.dirname(__FILE__)
        @ara_image = File.expand_path "../test-images/sample-ara.png", File.dirname(__FILE__)
        @fra_image = File.expand_path "../test-images/sample-fra.jpg", File.dirname(__FILE__)
      end

      def test_recognize
        assert_raises(ArgumentError) { OCR.new nil, nil }
        assert_raises(ArgumentError) { OCR.new @eng_image, :re }

        ocr = OCR.new @eng_image, :eng
        ocr.doc_path = nil
        assert_raises(ArgumentError) { ocr.recognize }
        ocr.lang = nil
        assert_raises(ArgumentError) { ocr.recognize }
        ocr.lang = :foo
        assert_raises(ArgumentError) { ocr.recognize }
        ocr.lang = :foo
        assert_raises(ArgumentError) { ocr.recognize }
      end

      def test_recognize_english
        ocr = OCR.new @eng_image, :eng
        assert_equal ocr.doc_path, @eng_image
        assert_equal ocr.lang, :eng
        assert_kind_of String, ocr.recognize
        assert_equal "OCR Testing", ocr.recognize.strip.delete("\n")
      end

      def test_recognize_arabic
        skip 'Travis CI does not have arabic tessdata .. skip.' if ENV['TRAVIS']

        ocr = OCR.new @ara_image, :ara
        assert_equal ocr.doc_path, @ara_image
        assert_equal ocr.lang, :ara
        assert_kind_of String, ocr.recognize
        assert_equal "تجربة تعرف طدونى\n\nهه", ocr.recognize.strip
      end

      def test_recognize_french
        skip 'Travis CI does not have french tessdata .. skip.' if ENV['TRAVIS']

        ocr = OCR.new @fra_image, :fra
        assert_equal ocr.doc_path, @fra_image
        assert_equal ocr.lang, :fra
        assert_kind_of String, ocr.recognize
        assert_equal "JE SERAI\n\nPUÈTE\nETTDI\n\n\"‘LÊî'E", ocr.recognize.strip
      end
    end

  end
end
