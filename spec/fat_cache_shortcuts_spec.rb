require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe FatCache::Shortcuts do

  describe 'when included in a class' do
    before do
      @manatee_class = Class.new
      @manatee_class.send(:include, FatCache::Shortcuts)
    end

    it 'provides a `cache`  method at the class level' do
      @manatee_class.should respond_to(:cache)
    end

    it 'provides a `cache`  method at the instance level' do
      @manatee_class.new.should respond_to(:cache)
    end

    describe 'the class level `cache` method' do
      it 'yields the FatCache class' do
        @manatee_class.cache
      end
    end

    describe 'the instance level `cache` method' do
      it 'yields the FatCache class' do
        @manatee_class.new.cache
      end
    end
  end

end
