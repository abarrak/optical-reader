require 'tmpdir'

ENV['RACK_ENV'] = 'test'
ENV['TMPDIR'] = Dir.tmpdir if ENV['TRAVIS']
puts Dir.tmpdir if ENV['TRAVIS']

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require_relative '../app'
require_relative '../api'

module OpticalReaderTest
  module Helper
    def errors_count response
      response.body.scan(/errors-explaination/).size
    end
  end
end
