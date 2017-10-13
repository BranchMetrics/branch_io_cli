module BranchIOCLI
  module Helper
    module AndroidHelper
      def add_keys_to_android_manifest(manifest, keys)
        add_metadata_to_manifest manifest, "io.branch.sdk.BranchKey", keys[:live] unless keys[:live].nil?
        add_metadata_to_manifest manifest, "io.branch.sdk.BranchKey.test", keys[:test] unless keys[:test].nil?
      end

      # TODO: Work on all XML/AndroidManifest formatting

      def add_metadata_to_manifest(manifest, key, value)
        element = manifest.elements["//manifest/application/meta-data[@android:name=\"#{key}\"]"]
        if element.nil?
          application = manifest.elements["//manifest/application"]
          application.add_element "meta-data", "android:name" => key, "android:value" => value
        else
          element.attributes["android:value"] = value
        end
      end

      def add_intent_filters_to_android_manifest(manifest, domains, uri_scheme, activity_name, remove_existing)
        if activity_name
          activity = manifest.elements["//manifest/application/activity[@android:name=\"#{activity_name}\""]
        else
          activity = find_activity manifest
        end

        raise "Failed to find an Activity in the Android manifest" if activity.nil?

        if remove_existing
          remove_existing_domains(activity)
        end

        add_intent_filter_to_activity activity, domains, uri_scheme
      end

      def find_activity(manifest)
        # try to infer the right activity
        # look for the first singleTask
        single_task_activity = manifest.elements["//manifest/application/activity[@android:launchMode=\"singleTask\"]"]
        return single_task_activity if single_task_activity

        # no singleTask activities. Take the first Activity
        # TODO: Add singleTask?
        manifest.elements["//manifest/application/activity"]
      end

      def add_intent_filter_to_activity(activity, domains, uri_scheme)
        # Add a single intent-filter with autoVerify and a data element for each domain and the optional uri_scheme
        intent_filter = REXML::Element.new "intent-filter"
        intent_filter.attributes["android:autoVerify"] = true
        intent_filter.add_element "action", "android:name" => "android.intent.action.VIEW"
        intent_filter.add_element "category", "android:name" => "android.intent.category.DEFAULT"
        intent_filter.add_element "category", "android:name" => "android.intent.category.BROWSABLE"
        intent_filter.elements << uri_scheme_data_element(uri_scheme) unless uri_scheme.nil?
        app_link_data_elements(domains).each { |e| intent_filter.elements << e }

        activity.add_element intent_filter
      end

      def remove_existing_domains(activity)
        # Find all intent-filters that include a data element with android:scheme
        # TODO: Can this be done with a single css/at_css call?
        activity.elements.each("//manifest//intent-filter") do |filter|
          filter.remove if filter.elements["data[@android:scheme]"]
        end
      end

      def app_link_data_elements(domains)
        domains.map do |domain|
          element = REXML::Element.new "data"
          element.attributes["android:scheme"] = "https"
          element.attributes["android:host"] = domain
          element
        end
      end

      def uri_scheme_data_element(uri_scheme)
        element = REXML::Element.new "data"
        element.attributes["android:scheme"] = uri_scheme
        element.attributes["android:host"] = "open"
        element
      end
    end
  end
end
