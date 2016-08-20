ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require_relative '../app'

module OpticalReaderTest
  module Helper
    def errors_count response
      response.body.scan(/errors-explaination/).size
    end
  end
end
