# frozen_string_literal: true

desc "Copy over the migration, and set cache"
namespace :solid_cache do
  task :install do
    Rails::Command.invoke :generate, [ "solid_cache:install" ]
  end
end


require "solid_cache/version"

desc "Pushing solid_cache_mongoid-#{SolidCache::VERSION}.gem to rubygems"
task :release do

  package = "pkg/solid_cache_mongoid-#{SolidCache::VERSION}.gem"
  ::FURY_CMD = "RUBYGEMS_API_KEY=#{ENV["RUBYGEMS_API_KEY"]} gem push #{package}"
  ::ERROR_PACKAGE_NOT_FOUND = "Error: gem #{package} is not found"

  if File.exist? package
    system(FURY_CMD, exception: true)
  else
    STDERR.puts ERROR_PACKAGE_NOT_FOUND
    exit 1
  end
end

