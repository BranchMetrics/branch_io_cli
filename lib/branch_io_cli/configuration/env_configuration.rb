module BranchIOCLI
  module Configuration
    class EnvConfiguration < Configuration
      class << self
        def summary
          "Output information about CLI environment."
        end
      end

      def initialize(options)
        @quiet = true
        super
      end

      def validate_options
        # Nothing to do for this command
      end
    end
  end
end
