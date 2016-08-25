require './app'
require './api'

map '/' do
  run OpticalReader::App
end

map '/api/v1' do
  run OpticalReader::Api
end
