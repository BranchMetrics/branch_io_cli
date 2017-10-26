require "branch_io_cli/helper/android_helper"
require "branch_io_cli/helper/ios_helper"
require "net/http"
require "pattern_patch"
require "set"

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

          File.open(options[:files], "w") do |file|
            file.write modified
          end
        end

        def fetch(url)
          response = Net::HTTP.get_response URI(url)

          case response
          when Net::HTTPSuccess
            response.body
          when Net::HTTPRedirection
            fetch response['location']
          else
            raise "Error fetching #{url}: #{response.code} #{response.message}"
          end
        end

        def download(url, dest)
          uri = URI(url)

          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
            request = Net::HTTP::Get.new uri

            http.request request do |response|
              case response
              when Net::HTTPSuccess
                bytes_downloaded = 0
                dots_reported = 0
                # report a dot every 100 kB
                per_dot = 102_400

                File.open dest, 'w' do |io|
                  response.read_body do |chunk|
                    io.write chunk

                    # print progress
                    bytes_downloaded += chunk.length
                    while (bytes_downloaded - per_dot * dots_reported) >= per_dot
                      print "."
                      dots_reported += 1
                    end
                    STDOUT.flush
                  end
                end
                say "\n"
              when Net::HTTPRedirection
                download response['location'], dest
              else
                raise "Error downloading #{url}: #{response.code} #{response.message}"
              end
            end
          end
        end

        def ensure_directory(path)
          return if path == "/" || path == "."
          parent = File.dirname path
          ensure_directory parent
          return if Dir.exist? path
          Dir.mkdir path
        end
      end
    end
  end
end
