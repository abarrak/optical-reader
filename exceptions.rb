module OpticalReader
  class AccessDeniedError < StandardError
    def initialize
      super 'API access denied.'
    end
  end
end
