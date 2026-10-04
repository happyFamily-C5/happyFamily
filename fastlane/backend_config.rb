# frozen_string_literal: true

require_relative "lib/backend_release_guard"

begin
  case ARGV.fetch(0, "")
  when "prepare"
    value = BackendReleaseGuard.expected(ENV.fetch("TESTFLIGHT_LANE", "beta"))
    BackendReleaseGuard.build_number(ENV["TESTFLIGHT_BUILD_NUMBER"])
    BackendReleaseGuard.verify_backend(value)
    BackendReleaseGuard.write_xcconfig(value, File.expand_path("../Config/Secrets.xcconfig", __dir__))
    puts "Backend preflight passed; temporary configuration created"
  else
    raise BackendReleaseGuard::Error, "Usage: ruby fastlane/backend_config.rb prepare"
  end
rescue BackendReleaseGuard::Error => error
  warn error.message
  exit 1
end
