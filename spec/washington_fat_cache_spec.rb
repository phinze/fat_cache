require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe WashingtonFatCache do
  after { WashingtonFatCache.reset! }

  describe 'get(key)' do

    it 'raises an exception if no data is stored for this key' do
      lambda { 
        WashingtonFatCache.get(:not_there) 
      }.should raise_error(/not_there/)
    end

  end

  describe 'store(key[, data])' do

    describe 'when called with key and data arguments' do
      it 'stores data for specified key' do
        WashingtonFatCache.store(:five_alive, 5)
        WashingtonFatCache.get(:five_alive).should == 5
      end

      it 'properly stores nil for key if explicitly specified' do
        WashingtonFatCache.store(:empty_inside, nil)
        WashingtonFatCache.get(:empty_inside).should be_nil
      end
    end

    describe 'when called with key and fetcher block' do
      it 'uses block as fetcher to retrieve data to store' do
        WashingtonFatCache.store(:fetched_from_block) { 'cheese sandwich' }
        WashingtonFatCache.get(:fetched_from_block).should == 'cheese sandwich'
      end
    end

  end

  describe 'lookup' do
  end

  describe 'index' do
  end

  describe 'invalidate(key)' do

    describe 'when no fetcher has been specified for key' do
      it 'returns the last value the cache had for the key' do
        WashingtonFatCache.store(:once_upon_a_time, 33)  
        retval = WashingtonFatCache.invalidate(:once_upon_a_time)
        retval.should == 33
      end

      it 'removes data stored for a given key' do
        WashingtonFatCache.store(:there_and_gone, 100)  
        WashingtonFatCache.invalidate(:there_and_gone)
        lambda {
          WashingtonFatCache.get(:there_and_gone)
        }.should raise_error(/there_and_gone/)
      end
    end

    describe 'when a fetcher has been specified for a key' do
    end
  end
end
