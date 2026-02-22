source 'https://rubygems.org'

ruby file: '.ruby-version'

# Framework
gem 'puma', '~> 6.6'
gem 'rails', '~> 8.0.0'

# Assets
gem 'importmap-rails'
gem 'propshaft'

# Database
# SQLite removed as per user request to move entirely to Meilisearch

gem 'bibtex-ruby', '~> 6.1' # Export bibtex citations
gem 'bootsnap', require: false # Reduces boot times through caching; required in config/boot.rb
gem 'kaminari' # Pagination
gem 'rack-attack' # Rate limiting and IP blocking
gem 'meilisearch' # Raw Meilisearch client (replacing meilisearch-rails which is AR-bound)
gem 'progressbar', '~> 1.13' # Used in the import task
gem 'view_component' # Reusable view components

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  gem 'memory_profiler'
  gem 'rack-mini-profiler'
  gem 'stackprof'

  # Linters and annotations
  gem 'annotaterb'
  gem 'htmlbeautifier', '~> 1.4.3'
  gem 'syntax_tree'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
end
