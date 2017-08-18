source "https://rubygems.org"
gem 'cocoapods', '1.2.1'

# Needed for s3 upload plugin
gem 'aws-sdk', '< 2'

# Needed to fix build errors on the buildbox. It will add additional quotes to the Podfile.lock
gem 'psych', '2.0.17'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval(File.read(plugins_path), binding) if File.exist?(plugins_path)
