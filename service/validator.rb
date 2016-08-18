module OpticalReader
  module Service

    class Validator
      attr_accessor :input
      attr_accessor :errors

      def initialize input, max_file_size = 10485760
        @input = input
        @errors = Hash.new
        @max_file_size = max_file_size
      end

      def validate_scan_input
        reset_errors!

        # process language input.
        validate_presence :language
        validate_choice :language, :choice?, OCR.langs
        # process file input.
        validate_presence :document
        if !@input[:document].nil? && !@input[:document][:tempfile].nil?
          validate_file :document, [:exceed_size?, :not_image?]
        end

        valid_input?
      end

      def validate_export_input
        !blank?(@input[:reviewed_text])
      end

      def validate_contact_input
        reset_errors!

        # process name
        validate_presence :name
        validate_length :name, :longer?, 80
        validate_length :name, :shorter?, 3
        # process subject.
        validate_presence :subject
        validate_length :subject, :longer?, 150
        validate_length :subject, :shorter?, 6
        # process email.
        validate_presence :email
        validate_email :email
        validate_length :email, :longer?, 150
        validate_length :email, :shorter?, 8
        # process type.
        validate_choice :type, :choice?, ['1', '2', '3', '4']
        # process Message.
        validate_presence :message
        validate_length :message, :longer?, 10000
        validate_length :message, :shorter?, 10

        valid_input?
      end

      private

        def reset_errors!
          @errors.clear
        end

        def valid_input?
          @errors.empty? ? true : false
        end

        # DELETE ME !!!
        # def validate field, validators
        #   val = lambda do |v, f|
        #     if send v, @input[f]
        #       key = format_t_key v
        #       @errors[f] ||= []
        #       @errors[f] << I18n.t("errors.#{key}", field: f(f))
        #     end
        #   end

        #   unless validators.respond_to? :each
        #     val.call validators, field
        #   else
        #     validators.each { |v| val.call v, field }
        #   end
        # end

        def validate_presence field
          if send :blank?, @input[field]
            @errors[field] ||= []
            @errors[field] << I18n.t("errors.blank", field: f(field))
          end
        end

        def validate_email field
          unless send :email?, @input[field]
            @errors[field] ||= []
            @errors[field] << I18n.t("errors.email", field: f(field))
          end
        end

        def validate_length field, validator, amount
          return if @input[field].nil?
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
          value.strip! if value.respond_to? :strip
          value.nil? || (value.respond_to?(:empty?) ? value.empty? : value.nil?)
        end

        def shorter? value, amount
          value.length < amount unless value.nil?
        end

        def longer? value, amount
          value.length > amount unless value.nil?
        end

        def email? value
          !(value =~ /\A([\w+\-]\.?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i).nil?
        end

        def choice? value, col
          col.include? value.to_s
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
