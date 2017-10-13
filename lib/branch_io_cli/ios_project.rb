require "xcodeproj"

module BranchIOCLI
  class IOSProject
    attr_accessor :path
    attr_accessor :xcodeproj

    def initialize(path)
      @path = path
    end

    def open
      raise "No path specified" if path.nil?
      @xcodeproj = Xcodeproj::Project.open path
    end
  end
end
