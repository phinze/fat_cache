require 'rubygems'
require 'ruby-debug'
class WashingtonFatCache
  @@fetchers = {}
  @@fatcache = {}
  class << self

    def store(*key_and_maybe_data, &fetcher)
      if key_and_maybe_data.length == 2 && fetcher.nil?
        key, data = key_and_maybe_data
        @@fatcache[key] = data
      elsif key_and_maybe_data.length == 1 && fetcher
        key = key_and_maybe_data.first
        @@fetchers[key] = fetcher
        @@fatcache[key] = fetcher.call
      else
        argstr   = "#{key_and_maybe_data.length} arguments"
        blockstr = (block_given?) ? 'a block' : 'no block'
        raise "Got #{argstr} and #{blockstr}, expected (key, data) or (key) { fetcher block }"
      end
    end

    def get(key)
      raise "no data for #{key}" unless @@fatcache.key?(key)
      @@fatcache[key]
    end

    def invalidate(key)
      @@fatcache.delete(key)
    end

    def reset!
      @@fetchers = {}
      @@fatcache = {}
    end
  
  end
end
