module BranchIOCLI
  module Configuration
    class EnvConfiguration < Configuration
      class << self
        def summary
          "Output information about CLI environment."
        end
      end

      def validate_options
      end
    end
  end
end
