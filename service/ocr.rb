# encoding: UTF-8
# 😁
module OpticalReader
  module Service
    class OCR

      LANGS = %W[afr amh ara asm aze aze_cyrl bel ben bod bos bul cat ceb ces chi_sim chi_tra chr cym dan dan_frak deu deu_frak dzo ell eng enm  epo equ est eus fas fin fra frk frm gle glg grc guj hat heb hin hrv hun iku ind isl ita ita_old jav jpn kan kat kat_old kaz khm kir kor kur lao lat lav lit mal mar mkd mlt msa mya nep nld nor ori osd pan pol por pus ron rus san sin slk slk_frak slv spa spa_old sqi srp srp_latn swa swe syr tam tel tgk tgl tha tir tur uig ukr urd uzb uzb_cyrl vie yid].freeze

      RTL_LANGS = %W[ara]

      LANGS_FULL_NAMES = ["Afrikaans", "Amharic", "Arabic", "Assamese", "Azerbaijani", "Azerbaijani - Cyrilic", "Belarusian", "Bengali", "Tibetan", "Bosnian", "Bulgarian", "Catalan; Valencian", "Cebuano", "Czech", "Chinese - Simplified", "Chinese - Traditional", "Cherokee", "Welsh", "Danish", "Danish - Fraktur", "German", "German - Fraktur", "Dzongkha", "Greek, Modern (1453-)", "English", "English, Middle (1100-1500)", "Esperanto", "Math/equation detection module", "Estonian", "Basque", "Persian", "Finnish", "French", "Frankish", "French, Middle (ca.1400-1600)", "Irish", "Galician", "Greek, Ancient (to 1453)", "Gujarati", "Haitian; Haitian Creole", "Hebrew", "Hindi", "Croatian", "Hungarian", "Inuktitut", "Indonesian", "Icelandic", "Italian", "Italian - Old", "Javanese", "Japanese", "Kannada", "Georgian", "Georgian - Old", "Kazakh", "Central Khmer", "Kirghiz; Kyrgyz", "Korean", "Kurdish", "Lao", "Latin", "Latvian", "Lithuanian", "Malayalam", "Marathi", "Macedonian", "Maltese", "Malay", "Burmese", "Nepali", "Dutch; Flemish", "Norwegian", "Oriya", "Orientation and script detection module", "Panjabi; Punjabi", "Polish", "Portuguese", "Pushto; Pashto", "Romanian; Moldavian; Moldovan", "Russian", "Sanskrit", "Sinhala; Sinhalese", "Slovak", "Slovak - Fraktur", "Slovenian", "Spanish; Castilian", "Spanish; Castilian - Old", "Albanian", "Serbian", "Serbian - Latin", "Swahili", "Swedish", "Syriac", "Tamil", "Telugu", "Tajik", "Tagalog", "Thai", "Tigrinya", "Turkish", "Uighur; Uyghur", "Ukrainian", "Urdu", "Uzbek", "Uzbek - Cyrilic", "Vietnamese", "Yiddish"] .freeze

      attr_accessor :doc_path
      attr_accessor :lang
      attr_reader :text

      def initialize doc_path, lang, pdf_only = false
        @doc_path = doc_path
        @lang = lang
        @pdf_only = pdf_only
        validate_params

        RTesseract.configure do |config|
          # to read images from urls.
          config.processor = "mini_magick"
        end
      end

      def validate_params
        raise ArgumentError.new 'Please supply a path for the document image.' if @doc_path.nil?
        raise ArgumentError.new 'Please supply a lang for the document image.' if @lang.nil?
        raise ArgumentError.new 'Language is not recognizable.' unless OCR.lang? @lang.to_s
      end

      def recognize
        validate_params
        unless @pdf_only
          RTesseract.new(@doc_path, lang: @lang).to_s
        else
          RTesseract.new(@doc_path, lang: @lang, options: :pdf).to_pdf
        end
      end

      def self.lang? l
        OCR::LANGS.include? l
      end

      def self.rtl? l
        OCR.RTL_LANGS.include? l
      end

    end
  end
end
