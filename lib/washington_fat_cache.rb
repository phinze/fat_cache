require 'rubygems'
require 'ruby-debug'
class WashingtonFatCache

  class << self
    @initted = false
    attr_accessor :fetchers, :fatcache, :indexed_fatcache

    def store(*key_and_maybe_data, &fetcher)
      init unless initted? # for first time store

      if key_and_maybe_data.length == 2 && fetcher.nil?
        key, data = key_and_maybe_data
        fatcache[key] = data
      elsif key_and_maybe_data.length == 1 && fetcher
        key = key_and_maybe_data.first
        fetchers[key] = fetcher
        fatcache[key] = fetcher.call
      else
        argstr   = "#{key_and_maybe_data.length} arguments"
        blockstr = (block_given?) ? 'a block' : 'no block'
        raise "Got #{argstr} and #{blockstr}, expected (key, data) or (key) { fetcher block }"
      end
    end

    def get(key)
      unless cached?(key)
        if fetchable?(key)
          fatcache[key] = fetchers[key].call
        else
          raise "no data for #{key}" 
        end
      end
      fatcache[key]
    end

    def lookup(key, options={})
      options = options.dup
      by      = [*options.delete(:by)]
      using   = [*options.delete(:using)]
      
      # create index if it doesn't exist
      index(key, by) unless indexed?(key, by)
     
      return indexed_fatcache[key][by][using]
    end

    def index(key, on)
      # must have cache data to work with
      ensure_cached(key)

      # ensure we're dealing with an array, we're such a friendly API!
      on = [*on]

      # init hash if we've never indexed for this key before
      indexed_fatcache[key] = {} unless indexed_fatcache.has_key?(key)

      raw_data = get(key)
      
      # calls each method specified in the `on` array once on each element in
      # the raw dataset, and uses the results of those calls to key this index
      indexed_fatcache[key][on] = raw_data.group_by { |x| on.map { |b| x.send(b) } }
    end

    def get_index(key, on)
      on = [*on]

      ensure_indexed(key, on)

      indexed_fatcache[key][on]
    end

    def ensure_cached(key)
      raise "no data for #{key}" unless cached?(key)
    end

    def ensure_indexed(key, on)
      ensure_cached(key)
      raise "no index for #{key} on #{on.inspect}" unless indexed?(key, on)
    end

    def cached?(key)
      fatcache && fatcache.has_key?(key)
    end

    def indexed?(key, on)
      indexed_fatcache                   && 
      indexed_fatcache.has_key?(key)     &&
      indexed_fatcache[key].has_key?(on)
    end

    def fetchable?(key)
      fetchers && fetchers.has_key?(key)
    end

    def invalidate(key)
      init unless initted? 
      
      fatcache.delete(key)
    end

    def reset!
      self.fetchers         = nil
      self.fatcache         = nil
      self.indexed_fatcache = nil
      @initted              = nil
    end

    protected

    def init
      self.fetchers         = {}
      self.fatcache         = {}
      self.indexed_fatcache = {}
      @initted             = true
    end

    def initted?
      @initted == true
    end
  
  end
end
