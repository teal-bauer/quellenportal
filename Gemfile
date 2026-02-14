source "https://rubygems.org"

ruby file: ".ruby-version"

# Framework
gem "rails", "~> 8.0.0"
gem "puma", "~> 6.6"

# Assets
gem "importmap-rails"
gem "propshaft"

# Database
gem "sqlite3", "~> 2.6" # Use SQLite for production
gem "activerecord-enhancedsqlite3-adapter", "~> 0.8.0" # Performance improvements for SQLite

gem "bibtex-ruby", "~> 6.1" # Export bibtex citations
gem "bootsnap", require: false # Reduces boot times through caching; required in config/boot.rb
gem "solid_queue" # Background job processing
gem "kaminari" # Pagination
gem "progressbar", "~> 1.13" # Used in the import task
gem "view_component" # Reusable view components

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  gem "rack-mini-profiler"
  gem "stackprof"
  gem "memory_profiler"

  # Linters and annotations
  gem "annotaterb"
  gem "syntax_tree"
  gem "htmlbeautifier", "~> 1.4.3"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
