require "active_support/core_ext/hash"
require_relative "android_helper"
require_relative "ios_helper"
require "net/http"
require "pastel"
require "set"
require "tty/progressbar"
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

        def download(url, dest, size: nil)
          uri = URI(url)

          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
            request = Net::HTTP::Get.new uri

            http.request request do |response|
              case response
              when Net::HTTPSuccess
                bytes_downloaded = 0
                if size
                  pastel = Pastel.new
                  green = pastel.on_green " "
                  yellow = pastel.on_yellow " "
                  progress = TTY::ProgressBar.new "[:bar] :percent (:eta)", total: 50, complete: green, incomplete: yellow
                end

                File.open dest, 'w' do |io|
                  response.read_body do |chunk|
                    io.write chunk

                    # print progress
                    bytes_downloaded += chunk.length
                    progress.ratio = bytes_downloaded.to_f / size.to_f if size
                  end
                end
                progress.finish if size
              when Net::HTTPRedirection
                download response['location'], dest, size: size
              else
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
