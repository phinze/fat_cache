require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe FatCache do
  # so we don't have leaky state
  after  { FatCache.reset! }

  describe 'get(key)' do
    it 'raises an exception if no data is stored for this key' do
      lambda { 
        FatCache.get(:not_there) 
      }.should raise_error(/not_there/)
    end

    describe 'when data has been invalidated for a key with a fetcher' do
      it 'uses a fetcher to get new data' do
        i = 0
        FatCache.store(:increment) { i += 1 }
        FatCache.invalidate(:increment)
        FatCache.get(:increment).should == 2
      end
    end
  end

  describe 'store(key[, data])' do
    describe 'when called with key and data arguments' do
      it 'stores data for specified key' do
        FatCache.store(:five_alive, 5)
        FatCache.get(:five_alive).should == 5
      end

      it 'properly stores nil for key if explicitly specified' do
        FatCache.store(:empty_inside, nil)
        FatCache.get(:empty_inside).should be_nil
      end
    end

    describe 'when called with key and fetcher block' do
      it 'uses block as fetcher to retrieve data to store' do
        FatCache.store(:fetched_from_block) { 'cheese sandwich' }
        FatCache.get(:fetched_from_block).should == 'cheese sandwich'
      end

      it 'calls the block only once, caching the data returned' do
        i = 0
        FatCache.store(:increment) { i += 1 }

        first_result = FatCache.get(:increment)
        second_result = FatCache.get(:increment)

        first_result.should == 1
        second_result.should == 1
      end
    end
  end

  describe 'lookup(key, :by => [:method_names], :using => [:index_key])' do
    it 'returns a records stored in the dataset specified by key, indexed by the specified methods, and with the following key to the index' do
      FatCache.store(:a_set, [0,1,2,3,4,5])
      result = FatCache.lookup(:a_set, :by => :odd?, :using => true)
      result.should == [1,3,5]
    end

    it 'works with multi-element index keys' do
      FatCache.store(:a_set, [0,1,2,3,4,5])
      result = FatCache.lookup(:a_set, :by => [:even?, :zero?], :using => [true, true])
      result.should == [0]
    end
  end

  describe 'get_index(key, on)' do
    it 'returns the given index for a key' do
      FatCache.store(:numbers, [0,1,2,3,4])
      FatCache.index(:numbers, :odd?)
      FatCache.get_index(:numbers, :odd?).should be_a Hash
    end

    it 'raises an error if no index exists for on specified key' do
      FatCache.store(:indexed_one_way, [123])
      FatCache.index(:indexed_one_way, :zero?)
      lambda {
        FatCache.get_index(:indexed_one_way, :odd?)
      }.should raise_error(/indexed_one_way.*odd?/)
    end
  end

  describe 'index(key, on) { optional_block }' do
    it 'raises an error if there is no raw data to index for specified key' do
      lambda {
        FatCache.index(:wishbone, :whats_the_story?)
      }.should raise_error(/wishbone/)
    end

    it 'raises an error if the elements of the dataset do not respond to the index key methods' do
      FatCache.store(:numbers, [1,2,3,4,5,6])
      lambda {
        FatCache.index(:numbers, :millionaire?)
      }.should raise_error(/millionaire?/)
    end
    
    describe 'given a dataset which responds to methods' do
      before do
        @fruit = [
          stub(:mango,  :grams_of_awesome => 3),
          stub(:banana, :grams_of_awesome => 10),
          stub(:apple,  :grams_of_awesome => 3)
        ]
        FatCache.store(:fruit, @fruit)
      end

      it 'calls each method specified in `on` array and uses the results as the index key' do
        FatCache.index(:fruit, [:grams_of_awesome])
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
        end
      end
    end

  end

  describe 'invalidate(key)' do
    describe 'when no fetcher has been specified for key' do
      it 'returns the last value the cache had for the key' do
        FatCache.store(:once_upon_a_time, 33)  
        retval = FatCache.invalidate(:once_upon_a_time)
        retval.should == 33
      end

      it 'removes data stored for a given key' do
        FatCache.store(:there_and_gone, 100)  
        FatCache.invalidate(:there_and_gone)
        lambda {
          FatCache.get(:there_and_gone)
        }.should raise_error(/there_and_gone/)
      end
    end

    describe 'when a fetcher has been specified for a key' do
      it 'does not clear out the fetcher, which can be used in the next lookup' do
        FatCache.store(:fetch_me) { "I've been fetched" }
        FatCache.invalidate(:fetch_me)
        FatCache.get(:fetch_me).should == "I've been fetched" 
      end
    end
  end
end
