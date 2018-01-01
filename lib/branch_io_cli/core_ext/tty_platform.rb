require "tty/platform"

module TTY
  class Platform
    def br_sierra?
      mac? && version.to_s == "16"
    end

    def br_high_sierra?
      mac? && version.to_s == "17"
    end
  end
end
