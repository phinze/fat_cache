require 'rubygems'
require 'ruby-debug'

class FatCache
  class CacheMiss < RuntimeError; end
  class AmbiguousHit < RuntimeError; end

  class << self
    @initted = false
    attr_accessor :fatcache, :indexed_fatcache
    attr_accessor :fetchers, :index_fetchers

    attr_accessor :logger

    # Simply store value as key
    def set(key, &fetcher)
      init unless initted? # for first time set

      fetchers[key] = fetcher
    end

    # Gets from cache or pays fetch cost if necessary to get, raises if none
    # available
    def get(key)
      unless cached?(key)
        if fetchable?(key)
          fetch!(key)
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
      
      fetch_index!(key, by) unless indexed?(key, by)

      indexed_fatcache[key][by][using]
    end

    def one(key, spec={})
      result = lookup(key, :by => spec.keys, :using => spec.values)
      if result && result.length > 1
        raise AmbiguousHit, "expected one record for #{key} with #{spec.inspect}, got #{result.inspect}" 
      end
      result.first if result # makes us return nil if result is nil
    end

    def one!(key, spec={})
      result = one(key, spec)
      raise CacheMiss, "count not find find #{key} with #{spec.inspect}" unless result
      result
    end

    def index(key, on, &block)
      on = [*on] # ensure we're dealing with an array, we're such a friendly API!

      ensure_fetchable(key)

      index_fetchers[key] = {} unless index_fetchers.has_key?(key)

      if block
        # make the cache available to the passed block, and ensure that
        # the returned value is wrapped in an array (to keep these keys in line
        # with the method sending strategy
        wrapped_block = lambda { |item| [*block.call(self, item)] }

        # pass each element of the raw data set into the block, which will
        # compute the key for us
        index_fetchers[key][on] = lambda { |data| data.group_by(&wrapped_block) }
      else
        # call each method specified in the `on` array once on each element in
        # the raw dataset, and use the results of those calls to key this index
        index_fetchers[key][on] = lambda { |data| data.group_by { |x| on.map { |b| x.send(b) } } }
      end
    end

    def invalidate!(key)
      return unless cached?(key)
      
      indexed_fatcache.delete(key)
      fatcache.delete(key)
    end

    def fetch!(key)
      ensure_fetchable(key)
      if logger
        start_time = Time.now
        logger.info "[fatcache] <#{key}> fetching ..."
      end
      fatcache[key] = fetchers[key].call(self)
      if logger
        took = Time.now - start_time
        logger.info "[fatcache] <#{key}> done! #{(took / 60).floor} minutes, #{(took % 60).floor} seconds"
      end
    end

    def fetch_index!(key, on)
      on = [*on]

      index(key, on) unless index_defined?(key, on)

      # init hash if we've never indexed for this key before
      indexed_fatcache[key] = {} unless indexed_fatcache.has_key?(key)

      raw_data = get(key)

      if logger
        start_time = Time.now
        logger.info "[fatcache] <#{key}> indexing on #{on.inspect} ..."
      end
      indexed_fatcache[key][on] = index_fetchers[key][on].call(raw_data)
      if logger
        took = Time.now - start_time
        logger.info "[fatcache] <#{key}> indexing on #{on.inspect} done! #{(took / 60).floor} minutes, #{(took % 60).floor} seconds"
      end
    end

    def get_index(key, on)
      on = [*on]

      ensure_indexed(key, on)

      indexed_fatcache[key][on]
    end

    def ensure_cached(key)
      raise "no data in cache for #{key}" unless cached?(key)
    end

    def ensure_indexed(key, on)
      raise "no index for #{key} on #{on.inspect}" unless indexed?(key, on)
    end

    def ensure_fetchable(key)
      raise "cannot fetch for #{key}" unless fetchable?(key)
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
    
    def index_defined?(key, on)
      index_fetchers                   && 
      index_fetchers.has_key?(key)     &&
      index_fetchers[key].has_key?(on)
    end

    def reset!
      self.fetchers         = nil
      self.index_fetchers   = nil
      self.fatcache         = nil
      self.indexed_fatcache = nil
      @initted              = nil
    end

    protected

    def init
      self.fetchers         = {}
      self.index_fetchers   = {}
      self.fatcache         = {}
      self.indexed_fatcache = {}
      @initted             = true
    end

    def initted?
      @initted == true
    end
  
  end
end
