require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe FatCache do
  # so we don't have leaky state
  after  { FatCache.reset! }

  describe 'get(key)' do
    it 'raises an exception if no data is set for this key' do
      lambda { 
        FatCache.get(:not_there) 
      }.should raise_error(/not_there/)
    end

    it 'uses specified fetcher to get new data' do
      needy = mock('needy')
      needy.should_receive(:called).once
      FatCache.set(:call_me) { needy.called }
      FatCache.get(:call_me)
    end

    it 'calls the block only once, caching the data returned' do
      i = 0
      FatCache.set(:increment) { i += 1 }

      first_result = FatCache.get(:increment)
      second_result = FatCache.get(:increment)

      first_result.should == 1
      second_result.should == 1
    end
  end

  describe 'set(key) { fetcher_block }' do
    it 'does not evaluate fetcher_block' do
      independent = mock('independent')
      independent.should_not_receive(:called)
      FatCache.set(:dont_need_you) { independent.called }
    end

    it 'makes data available on get' do
      FatCache.set(:fetched_from_block) { 'cheese sandwich' }
      FatCache.get(:fetched_from_block).should == 'cheese sandwich'
    end
  end

  describe 'fetch!(key)' do
    it 'activates evaluation of a fetcher block' do
      needy = mock('needy')
      needy.should_receive(:called)
      FatCache.set(:call_me) { needy.called }
      FatCache.fetch!(:call_me)
    end

    it 'prevents evaluation fetcher block in future gets' do
      fool_me_once = stub('fool_me_once')
      fool_me_once.should_receive(:fooled!).once

      FatCache.set(:dont_fool_me_twice) { fool_me_once.fooled! }
      FatCache.fetch!(:dont_fool_me_twice)
      FatCache.get(:dont_fool_me_twice)
    end

    describe 'when logger is set' do
      before do
        @logger = stub('fakelogger')
        FatCache.logger = @logger
      end
      after  { FatCache.logger = nil }
      it 'prints out once before beginning and once after' do
        FatCache.set(:you) { 'are my sunshine' }
        @logger.should_receive(:info).with(/you/).twice
        FatCache.fetch!(:you)
      end
    end
  end

  describe 'lookup(key, :by => [:method_names], :using => [:index_key])' do
    it 'returns a records set in the dataset specified by key, indexed by the specified methods, and with the following key to the index' do
      FatCache.set(:a_set) { [0,1,2,3,4,5] }
      result = FatCache.lookup(:a_set, :by => :odd?, :using => true)
      result.should == [1,3,5]
    end

    it 'works with multi-element index keys' do
      FatCache.set(:a_set) { [0,1,2,3,4,5] }
      result = FatCache.lookup(:a_set, :by => [:even?, :zero?], :using => [true, true])
      result.should == [0]
    end
  end

  describe 'get_index(key, on)' do
    it 'returns the given index for a key' do
      FatCache.set(:numbers) { [0,1,2,3,4] }
      FatCache.index(:numbers, :odd?)
      FatCache.fetch_index!(:numbers, :odd?)
      FatCache.get_index(:numbers, :odd?).should be_a Hash
    end

    it 'raises an error if no index exists for on specified key' do
      FatCache.set(:indexed_one_way) { [123] }
      FatCache.index(:indexed_one_way, :zero?)
      lambda {
        FatCache.get_index(:indexed_one_way, :odd?)
      }.should raise_error(/indexed_one_way.*odd?/)
    end
  end

  describe 'one(key, spec)' do

    describe 'one', :shared => true do
      it 'returns one record found in the dataset specified by key, with a spec matching the spec hash' do
        FatCache.set(:numbers) { [0,1,2,3,4] }
        FatCache.one(:numbers, :zero? => true).should == 0
      end

      it 'raises an error if more than one record matches spec' do
        FatCache.set(:numbers) { [0,1,2,3,4] }
        lambda {
          FatCache.one(:numbers, :odd? => false)
        }.should raise_error(FatCache::AmbiguousHit)
      end

      it 'raises an error if no cache exists for key' do
        lambda {
          FatCache.one(:no_way, :not => 'here')
        }.should raise_error(/no_way/)
      end
    end

    it_should_behave_like 'one'

    it 'returns nil if no record found in index' do
      FatCache.set(:numbers) { [1,2,3,4] }
      FatCache.one(:numbers, :zero? => true).should be_nil
    end
  end

  describe 'one!(key, spec)' do
    it_should_behave_like 'one'

    it 'raises an error if no record found in index' do
      FatCache.set(:numbers) { [1,2,3,4] }
      lambda {
        FatCache.one!(:numbers, :zero? => true)
      }.should raise_error(FatCache::CacheMiss)
    end
  end

  describe 'index(key, on) { optional_block }' do
    it 'raises an error if there is no raw data to index for specified key' do
      lambda {
        FatCache.index(:wishbone, :whats_the_story?)
      }.should raise_error(/wishbone/)
    end

    it 'raises an error if the elements of the dataset do not respond to the index key methods' do
      FatCache.set(:numbers) { [1,2,3,4,5,6] }
      lambda {
        FatCache.index(:numbers, :millionaire?)
        FatCache.fetch_index!(:numbers, :millionaire?)
      }.should raise_error(/millionaire?/)
    end
    
    describe 'given a dataset which responds to methods' do
      before do
        @fruit = [
          stub(:mango,  :grams_of_awesome => 3),
          stub(:banana, :grams_of_awesome => 10),
          stub(:apple,  :grams_of_awesome => 3)
        ]
        FatCache.set(:fruit) { @fruit }
      end

      it 'calls each method specified in `on` array and uses the results as the index key' do
        FatCache.index(:fruit, [:grams_of_awesome])
        FatCache.fetch_index!(:fruit, [:grams_of_awesome])
        index = FatCache.get_index(:fruit, :grams_of_awesome)
        index.keys.should =~ [[3],[10]]
      end

      describe 'when the optional block is specified' do
        it 'does not send the symbols specified for `on` to the dataset members' do
          FatCache.get(:fruit).each { |f| f.should_not_receive(:grams_of_awesome) }
          FatCache.index(:fruit, :grams_of_awesome) { :dont_care }
        end
        
        it 'indexes the dataset based on the return value of the block' do
          FatCache.index(:fruit, :grams_of_awesome) { :so_many }
          results = FatCache.lookup(:fruit, :by => :grams_of_awesome, :using => :so_many)
          results.should =~ @fruit
        end

        it 'passes itself into the block as the first argument' do
          FatCache.index(:fruit, :grams_of_awesome) { |cache, _| 
            cache.should == FatCache
          }
        end

        it 'passes each item into the block as the second argument' do
          FatCache.get(:fruit).each { |f| f.should_receive(:seen) }
          FatCache.index(:fruit, :grams_of_awesome) { |_, item| item.seen }
          FatCache.fetch_index!(:fruit, :grams_of_awesome)
        end
      end
    end

  end

  describe 'fetch_index!(key, on)' do
    it 'actually runs through and fetches index'
    it 'defines an index based on the key if one does not exist'
    it 'uses the existing index if one is defined'
    describe 'when logger is set' do
      before do
        @logger = stub('fakelogger')
      end
      after  { FatCache.logger = nil }
      it 'prints out once before beginning and once after' do
        FatCache.set(:you) { 'are my sunshine' }
        FatCache.fetch!(:you)

        FatCache.logger = @logger
        @logger.should_receive(:info).twice { |str|
          str.should match(/you/)
          str.should match(/index/)
          str.should match(/nil/)
        }

        FatCache.fetch_index!(:you, :nil?)
      end
    end
  end

  describe 'invalidate!(key)' do
    describe 'when no fetcher has been specified for key' do
      it 'returns the last value the cache had for the key' do
        FatCache.set(:once_upon_a_time) { 33 }  
        FatCache.get(:once_upon_a_time)
        retval = FatCache.invalidate!(:once_upon_a_time)
        retval.should == 33
      end

      it 'causes data to be retreived from the fetcher again' do
        i = 0
        FatCache.set(:increment) { i += 1 }
        FatCache.get(:increment).should == 1
        FatCache.invalidate!(:increment)
        FatCache.get(:increment).should == 2
      end
    end

    describe 'when a fetcher has been specified for a key' do
      it 'does not clear out the fetcher, which can be used in the next lookup' do
        FatCache.set(:fetch_me) { "I've been fetched" }
        FatCache.invalidate!(:fetch_me)
        FatCache.get(:fetch_me).should == "I've been fetched" 
      end
    end
  end


  describe 'dump and load' do
    it 'marshals out the data in the main cache' do
      FatCache.set(:fetchy_poo) { "Oh what a fetching young chap" }
      FatCache.get(:fetchy_poo) # get it fetched
      data = FatCache.dump
      FatCache.reset!
      FatCache.load!(data)
      FatCache.get(:fetchy_poo).should == "Oh what a fetching young chap" 
    end

    it 'marshals out the indexed data in the main cache' do
      FatCache.set(:numbers) { [0,1,2,3,4] }
      FatCache.index(:numbers, :odd?)
      FatCache.fetch_index!(:numbers, :odd?)
      data = FatCache.dump
      FatCache.reset!
      FatCache.load!(data)
      FatCache.lookup(:numbers, :by => :odd?, :using => true).should == [1,3]
    end

    describe 'after a dump and load' do
      before do
        FatCache.set(:numbers) { [0,1,2,3,4] }
        FatCache.index(:numbers, :odd?)
        FatCache.fetch_index!(:numbers, :odd?)
        data = FatCache.dump
        FatCache.reset!
        FatCache.load!(data)
      end
      it 'allows new indexes to be defined' do
        FatCache.index(:numbers, :even?)
        FatCache.lookup(:numbers, :by => :even?, :using => true).should == [0,2,4]
      end

      it 'does not know about fetchers, so invalidate is permanant' do
        FatCache.invalidate!(:numbers)
        lambda {
          FatCache.get(:numbers)
        }.should raise_error FatCache::CacheMiss
      end
    end
  end
end
