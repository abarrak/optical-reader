require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb', 'test/*/*_test.rb']
  t.verbose = false   # false to hide file list
end

task :default => [:test]
