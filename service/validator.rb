## ----------------------------------------------------
#             Optical Reader [2016]
#   :summary: An online ocr service based on Tesseract.
#   :author:  Abdullah Barrak (github.com/abarrak).
## ----------------------------------------------------

module OpticalReader
  module Service

    class Validator
      attr_accessor :errors

      def initialize input
        @input = input
        @errors = Hash.new
      end

      def validate_scan_input
        # process language input.
        validate :language, :blank?
        validate_choice :language, :choice?, OCR.langs

        # process file input.
        @max_file_size = 10485760
        validate :document, :blank?

        if !@input[:document].nil? && !@input[:document][:tempfile].nil?
          validate_file :document, [:exceed_size?, :not_image?]
        end

        valid_input?
      end

      def validate_export_input
        !blank?(@input[:reviewed_text])
      end

      def validate_contact_input
        # process name
        validate :name, :blank?
        validate_length :name, :longer?, 80
        validate_length :name, :shorter?, 3

        # process subject.
        validate :subject, :blank?
        validate_length :subject, :longer?, 150
        validate_length :subject, :shorter?, 6

        # process email.
        validate :email, [:blank?, :email?]
        validate_length :email, :longer?, 150
        validate_length :email, :shorter?, 8

        # process type.
        validate_choice :type, :choice?, ['', '1', '2', '3', '4']

        # process Message.
        validate :message, :blank?
        validate_length :message, :longer?, 10000
        validate_length :message, :shorter?, 10

        valid_input?
      end

      private

        def valid_input?
          @errors.empty? ? true : false
        end

        def validate field, validators
          val = lambda do |v, f|
            if send v, @input[f]
              key = format_t_key v
              @errors[f] ||= []
              @errors[f] << I18n.t("errors.#{key}", field: f(f))
            end
          end

          unless validators.respond_to? :each
            val.call validators, field
          else
            validators.each do |v|
              val.call v, field
            end
          end
        end

        def validate_length field, validator, amount
          if send validator, @input[field], amount
            key = format_t_key validator
            @errors[field] ||= []
            @errors[field] << I18n.t("errors.#{key}", field: f(field), amount: amount)
          end
        end

        def validate_choice field, validator, list
          unless send validator, @input[field], list
            key = format_t_key validator
            @errors[field] ||= []
            @errors[field] << I18n.t("errors.#{key}", field: f(field))
          end
        end

        def validate_file field, validators
          validators.each do |validator|
            if send validator, @input[field][:tempfile]
              key = format_t_key validator
              @errors[field] ||= []
              @errors[field] << I18n.t("errors.#{key}", field: f(field))
            end
          end
        end

        def blank? value
          value.strip! if value.respond_to? :strip?
          value.nil? || (value.respond_to?(:empty?) ? value.empty? : value.nil?)
        end

        def shorter? value, amount
          value.length < amount unless value.nil?
        end

        def longer? value, amount
          value.length > amount unless value.nil?
        end

        def email? value
          (value =~ /\A([\w+\-]\.?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i).nil?
        end

        def choice? value, col
          col.include? value
        end

        def exceed_size? value
          value.size > @max_file_size
        end

        def not_image? value
          # better to not validate on extensions.
          # !%w[jpg jpeg gif png].include? value.path.split('.')[-1].downcase

          !%w[jpg jpeg gif png].include? FastImage.type(value.path).to_s
        end

        def format_t_key validator_name
          validator_name.to_s.split('?')[0]
        end

        # localize field names
        def f field
          I18n.t "fields.#{field.to_s}"
        end
    end

  end
end
