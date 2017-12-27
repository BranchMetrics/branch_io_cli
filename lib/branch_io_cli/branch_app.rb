require "active_support/core_ext/hash"
require "json"
require "branch_io_cli/helper"

module BranchIOCLI
  class BranchApp
    class << self
      def [](key)
        fetch key
      end

      def fetch(key, cache: true)
        @apps ||= {}
        @apps[key] = new(key) unless cache && @apps[key]
        @apps[key]
      end
    end

    API_ENDPOINT = "https://api.branch.io/v1/app-link-settings/"

    attr_reader :key
    attr_reader :alternate_short_url_domain
    attr_reader :android_package_name
    attr_reader :android_uri_scheme
    attr_reader :default_short_url_domain
    attr_reader :ios_bundle_id
    attr_reader :ios_team_id
    attr_reader :ios_uri_scheme
    attr_reader :short_url_domain

    def initialize(key)
      @key = key

      say "Fetching configuration from Branch Dashboard for #{key}."

      @hash = JSON.parse(Helper::BranchHelper.fetch("#{API_ENDPOINT}#{key}")).symbolize_keys.merge key: key

      say "Done ✅"

      @alternate_short_url_domain = @hash[:alternate_short_url_domain]
      @android_package_name = @hash[:android_package_name]
      @android_uri_scheme = @hash[:android_uri_scheme]
      @default_short_url_domain = @hash[:default_short_url_domain]
      @ios_bundle_id = @hash[:ios_bundle_id]
      @ios_team_id = @hash[:ios_team_id]
      @ios_uri_scheme = @hash[:ios_uri_scheme]
      @short_url_domain = @hash[:short_url_domain]
    end

    def domains
      [alternate_short_url_domain, default_short_url_domain, short_url_domain].compact.uniq
    end

    def to_hash
      @hash
    end

    def to_s
      # Changes
      # {:key1=>"value1", :key2=>"value2"}
      # to
      # key1="value1" key2="value2"
      @hash.to_s.sub(/^\{\:/, '').sub(/\}$/, '').gsub(/, \:/, ' ').gsub(/\=\>/, '=')
    end

    def inspect
      "#<BranchIOCLI::BranchApp #{self}>"
    end
  end
end
