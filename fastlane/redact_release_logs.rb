# frozen_string_literal: true

require "fileutils"

module ReleaseLogRedaction
  def self.redact(content, env = ENV)
    patterns = env.select { |name, _value| name.match?(/KEY|TOKEN|PASSWORD|BACKEND_URL/) }
                  .values.reject(&:empty?).sort_by { |value| -value.length }
    patterns.each do |value|
      content = content.gsub(value, "[REDACTED]").gsub(value.sub("https://", "https:/$()/"), "[REDACTED]")
    end
    content.gsub(/sb_(?:publishable|secret)_[A-Za-z0-9_-]+/, "[REDACTED]")
           .gsub(/eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/, "[REDACTED]")
           .gsub(/-----BEGIN .*?PRIVATE KEY-----.*?-----END .*?PRIVATE KEY-----/m, "[REDACTED]")
  end
end

if $PROGRAM_NAME == __FILE__
  destination = ARGV.fetch(0)
  FileUtils.mkdir_p(destination)
  paths = Dir.glob(File.expand_path("~/Library/Logs/gym/*.log")) +
          Dir.glob(File.expand_path("~/Library/Logs/fastlane/**/*.log"))
  paths.each_with_index do |path, index|
    content = File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace)
    File.write(File.join(destination, "release-#{index}.log"), ReleaseLogRedaction.redact(content))
  end
end
