# frozen_string_literal: true

desc "Copy over the migration, and set cache"
namespace :solid_cache_mongoid do
  task :install do
    Rails::Command.invoke :generate, [ "solid_cache_mongoid:install" ]
  end
end


require "solid_cache_mongoid/version"

desc "Pushing solid_cache_mongoid-#{SolidCacheMongoid::VERSION}.gem to rubygems"
task :release do
  package = "pkg/solid_cache_mongoid-#{SolidCacheMongoid::VERSION}.gem"
  ::FURY_CMD = "gem push #{package}"
  ::ERROR_PACKAGE_NOT_FOUND = "Error: gem #{package} is not found"

  if File.exist? package
    system(FURY_CMD, exception: true)
  else
    STDERR.puts ERROR_PACKAGE_NOT_FOUND
    exit 1
  end
end
