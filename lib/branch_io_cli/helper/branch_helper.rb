require "branch_io_cli/helper/android_helper"
require "branch_io_cli/helper/ios_helper"
require "pattern_patch"

module BranchIOCLI
  module Helper
    class BranchHelper
      class << self
        attr_accessor :changes # An array of file paths (Strings) that were modified
        attr_accessor :errors # An array of error messages (Strings) from validation

        include AndroidHelper
        include IOSHelper

        def add_change(change)
          @changes ||= Set.new
          @changes << change.to_s
        end

        # Shim around PatternPatch for now
        def apply_patch(options)
          modified = File.open(options[:files]) do |file|
            PatternPatch::Utilities.apply_patch file.read,
                                                options[:regexp],
                                                options[:text],
                                                options[:global],
                                                options[:mode],
                                                options[:offset] || 0
          end

          File.open(options[:file], "w") do |file|
            file.write modified
          end
        end
      end
    end
  end
end
