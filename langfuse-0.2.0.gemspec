# frozen_string_literal: true

# stub: langfuse 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = 'ruby-langfuse'
  s.version = '0.2.0'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.require_paths = ['lib']
  s.authors = ['Langfuse']
  s.description = "Langfuse is an open source observability platform for LLM applications. This is the Ruby client for Langfuse's API. Rough first alpha"
  s.email = ['rwpannick@gmail.com']
  s.homepage = 'https://github.com/b08x/ruby-langfuse'
  s.licenses = ['MIT']
  s.required_ruby_version = Gem::Requirement.new('>= 2.7.0')
  s.summary = 'Ruby SDK for the Langfuse observability platform'

  s.installed_by_version = '3.6.8'

  s.add_dependency('concurrent-ruby', ['~> 1.2'])
  s.add_dependency('sorbet-runtime', ['~> 0.5'])
  s.add_development_dependency('bundler', ['~> 2.0'])
  s.add_development_dependency('faker', ['~> 3.2'])
  s.add_development_dependency('memory_profiler', ['~> 1.0'])
  s.add_development_dependency('rake', ['~> 13.0'])
  s.add_development_dependency('rspec', ['~> 3.12'])
  s.add_development_dependency('sidekiq', ['~> 6.5'])
  s.add_development_dependency('simplecov', ['~> 0.22'])
  s.add_development_dependency('sorbet', ['~> 0.5'])
  s.add_development_dependency('tapioca', ['~> 0.11'])
  s.add_development_dependency('timecop', ['~> 0.9'])
  s.add_development_dependency('vcr', ['~> 6.1'])
  s.add_development_dependency('webmock', ['~> 3.18'])
  s.metadata['rubygems_mfa_required'] = 'true'
end
