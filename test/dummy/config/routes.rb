Rails.application.routes.draw do
  mount SolidCacheMongoid::Engine => "/solid_cache_mongoid"
end
