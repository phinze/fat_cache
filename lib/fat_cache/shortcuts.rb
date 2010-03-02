class FatCache
  module Shortcuts
    def self.included(base)
      base.extend ClassMethods 
    end

    module ClassMethods
      def cache
        FatCache
      end
    end

    def cache
      FatCache
    end
  end
end
