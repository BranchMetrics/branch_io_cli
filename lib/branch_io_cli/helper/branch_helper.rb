require "active_support/core_ext/hash"
require_relative "android_helper"
require_relative "ios_helper"
require "net/http"
require "set"
require "tty/spinner"

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

        def fetch(url, spin: true)
          if spin
            @spinner = TTY::Spinner.new "[:spinner] GET #{url}.", format: :flip
            @spinner.auto_spin
          end

          response = Net::HTTP.get_response URI(url)

          case response
          when Net::HTTPSuccess
            @spinner.success "#{response.code} #{response.message}" if @spinner
            @spinner = nil
            response.body
          when Net::HTTPRedirection
            fetch response['location'], spin: false
          else
            @spinner.error "#{response.code} #{response.message}" if @spinner
            @spinner = nil
            raise "Error fetching #{url}: #{response.code} #{response.message}"
          end
        end

        def download(url, dest, spin: true)
          uri = URI(url)

          @spinner = TTY::Spinner.new "[:spinner] GET #{uri}.", format: :flip if spin

          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
            request = Net::HTTP::Get.new uri

            http.request request do |response|
              case response
              when Net::HTTPSuccess
                bytes_downloaded = 0
                dots_reported = 0
                # spin every 100 kB
                per_dot = 102_400

                File.open dest, 'w' do |io|
                  response.read_body do |chunk|
                    io.write chunk

                    # print progress
                    bytes_downloaded += chunk.length
                    while (bytes_downloaded - per_dot * dots_reported) >= per_dot
                      @spinner.spin
                      dots_reported += 1
                    end
                  end
                end
                @spinner.success "#{response.code} #{response.message}" if @spinner
                @spinner = nil
              when Net::HTTPRedirection
                download response['location'], dest, spin: false
              else
                @spinner.error "#{response.code} #{response.message}" if @spinner
                @spinner = nil
                raise "Error downloading #{url}: #{response.code} #{response.message}"
              end
            end
          end
        end

        def domains(apps)
          apps.inject Set.new do |result, k, v|
            next result unless v
            result + v.domains
          end
        end
      end
    end
  end
end
