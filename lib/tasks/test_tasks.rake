require 'minitest/test_task'

namespace :test do
  Minitest::TestTask.create(:benchmark) do |t|
    t.libs << 'test'
    t.libs << 'lib'
    t.warning = false
    t.test_globs = ['test/**/*_benchmark.rb']
  end
end
