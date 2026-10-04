# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "tmpdir"
require "uri"

# No error contains configuration values: callers may safely report these errors
# in CI. Publishable keys belong in the client, never in diagnostics/artifacts.
module BackendReleaseGuard
  class Error < StandardError; end

  LANES = {
    "beta" => ["production", "Release", "com.academy.hendraaaa.happyFamily"],
    "staging_beta" => ["staging", "Staging", "com.academy.hendraaaa.happyFamily.staging"]
  }.freeze
  STAGING_REF = "tdpvtdblphojutjifdlc"

  Expected = Struct.new(:environment, :configuration, :bundle_id, :project_ref, :url, :key, keyword_init: true)

  def self.expected(lane, env = ENV)
    environment, configuration, bundle_id = LANES.fetch(lane) { raise Error, "Unsupported TestFlight lane" }
    prefix = "KUMPUL_#{environment.upcase}"
    project_ref = env.fetch("#{prefix}_PROJECT_REF", "").to_s
    raise Error, "Missing or invalid #{prefix}_PROJECT_REF" unless project_ref.match?(/\A[a-z]{20}\z/)
    raise Error, "Staging project does not match the reset target" if environment == "staging" && project_ref != STAGING_REF
    raise Error, "Production must not use the staging project" if environment == "production" && project_ref == STAGING_REF

    value = Expected.new(environment: environment, configuration: configuration, bundle_id: bundle_id,
                         project_ref: project_ref, url: env.fetch("#{prefix}_BACKEND_URL", "").to_s,
                         key: env.fetch("#{prefix}_PUBLISHABLE_KEY", "").to_s)
    validate_client(value.url, value.key, value.project_ref)
    value.freeze
  end

  def self.validate_client(url, key, project_ref)
    uri = URI.parse(url)
    valid_url = uri.scheme == "https" && uri.host == "#{project_ref}.supabase.co" &&
                uri.userinfo.nil? && uri.port == 443 && [nil, ""].include?(uri.path) &&
                uri.query.nil? && uri.fragment.nil? && url == "https://#{project_ref}.supabase.co"
    raise Error, "Backend URL must be the selected hosted project origin" unless valid_url
    raise Error, "Missing, placeholder, or unresolved client key" if key.empty? || key != key.strip ||
      key.match?(/\s|\$\(|replace-with|placeholder/i)

    return true if key.match?(/\Asb_publishable_[A-Za-z0-9_-]+\z/)

    segments = key.split(".")
    raise Error, "Only publishable or legacy anon keys may be embedded" unless segments.length == 3
    claims = JSON.parse(Base64.urlsafe_decode64(segments[1]))
    raise Error, "Legacy client key must have anon role and match the project" unless
      claims.is_a?(Hash) && claims["role"] == "anon" && claims["ref"] == project_ref
    true
  rescue URI::InvalidURIError, JSON::ParserError, ArgumentError
    raise Error, "Malformed backend URL or client key"
  end

  # Auth's health endpoint is a read-only gateway check. Modern opaque keys
  # cannot be associated with a project by decoding them; the gateway checks it.
  def self.verify_backend(value, transport: nil)
    uri = URI("#{value.url}/auth/v1/health")
    request = Net::HTTP::Get.new(uri)
    request["apikey"] = value.key
    response = if transport
                 transport.call(uri, request)
               else
                 Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
                   http.request(request)
                 end
               end
    raise Error, "Selected backend rejected the client configuration" unless response.code == "200"
    health = JSON.parse(response.body)
    raise Error, "Backend health response is invalid" unless health["name"] == "GoTrue" && health["version"].is_a?(String)
    true
  rescue Error
    raise
  rescue StandardError
    raise Error, "Backend health check failed; upload is blocked"
  end

  def self.write_xcconfig(value, path)
    prefix = "KUMPUL_#{value.environment.upcase}"
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      file.puts("// Temporary TestFlight configuration; never commit or upload.")
      file.puts("#{prefix}_BACKEND_URL = #{value.url.sub('https://', 'https:/$()/')}")
      file.puts("#{prefix}_PUBLISHABLE_KEY = #{value.key}")
    end
  rescue SystemCallError
    raise Error, "Cannot create temporary backend configuration (existing files are preserved)"
  end

  def self.build_number(value)
    number = value.to_s
    raise Error, "Build number must contain one to three numeric components" unless number.match?(/\A\d+(?:\.\d+){0,2}\z/)
    number
  end

  def self.verify_values(values, expected, number, settings: false)
    names = if settings
              %w[KUMPUL_BACKEND_ENVIRONMENT KUMPUL_BACKEND_URL KUMPUL_BACKEND_PUBLISHABLE_KEY PRODUCT_BUNDLE_IDENTIFIER CURRENT_PROJECT_VERSION]
            else
              %w[KumpulBackendEnvironment KumpulBackendURL KumpulBackendPublishableKey CFBundleIdentifier CFBundleVersion]
            end
    actual = names.map { |name| values[name] }
    wanted = [expected.environment, expected.url, expected.key, expected.bundle_id, build_number(number)]
    names.zip(actual, wanted).each do |name, found, required|
      raise Error, "Release configuration mismatch: #{name}" unless found == required
    end
    true
  end

  def self.verify_build_settings(expected, number, root:, executor: Open3.method(:capture3))
    stdout, _stderr, status = executor.call(
      "xcodebuild", "-project", File.join(root, "happyFamily.xcodeproj"), "-scheme", "happyFamily",
      "-configuration", expected.configuration, "-sdk", "iphoneos", "-showBuildSettings", "-json",
      "CURRENT_PROJECT_VERSION=#{build_number(number)}", chdir: root
    )
    raise Error, "Could not inspect effective build settings" unless status.success?
    targets = JSON.parse(stdout).select { |target| target["target"] == "happyFamily" }
    raise Error, "Expected exactly one happyFamily application target" unless targets.length == 1
    verify_values(targets.first.fetch("buildSettings"), expected, number, settings: true)
  rescue JSON::ParserError, KeyError
    raise Error, "Effective build settings are unreadable"
  end

  def self.read_plist(path)
    raise Error, "Application Info.plist is missing" unless File.file?(path)
    stdout, _stderr, status = Open3.capture3("python3", "-c",
      "import json,plistlib,sys; print(json.dumps(plistlib.load(open(sys.argv[1], 'rb'))))", path)
    raise Error, "Application Info.plist is unreadable" unless status.success?
    JSON.parse(stdout)
  rescue JSON::ParserError
    raise Error, "Application Info.plist is unreadable"
  end

  def self.verify_app_directory(directory, expected, number)
    apps = Dir.glob(File.join(directory, "*.app")).select { |path| File.directory?(path) }
    raise Error, "Expected exactly one application in the release artifact" unless apps.length == 1
    verify_values(read_plist(File.join(apps.first, "Info.plist")), expected, number)
  end

  def self.verify_archive(path, expected, number)
    raise Error, "Release archive is missing" unless File.directory?(path)
    verify_app_directory(File.join(path, "Products", "Applications"), expected, number)
  end

  def self.verify_ipa(path, expected, number)
    raise Error, "Release IPA is missing" unless path.is_a?(String) && File.file?(path)
    listing, _stderr, status = Open3.capture3("unzip", "-Z1", path)
    raise Error, "Release IPA is unreadable" unless status.success?
    raise Error, "Release IPA contains unsafe paths" if listing.lines.any? { |line|
      line.start_with?("/", "\\") || line.strip.split(/[\\\/]/).include?("..")
    }
    Dir.mktmpdir("happyfamily-ipa-") do |directory|
      _stdout, _stderr, status = Open3.capture3("unzip", "-q", path, "-d", directory)
      raise Error, "Release IPA could not be inspected" unless status.success?
      verify_app_directory(File.join(directory, "Payload"), expected, number)
    end
  end

  # Both production lanes use this gate immediately before the explicit upload.
  # Keeping the uploader inside the gate makes failure ordering testable.
  def self.upload_validated(archive:, ipa:, expected:, number:, output_directory:)
    raise Error, "IPA does not belong to this build output" unless ipa.is_a?(String) &&
      File.dirname(File.realpath(ipa)) == File.realpath(output_directory)
    verify_archive(archive, expected, number)
    verify_ipa(ipa, expected, number)
    yield File.realpath(ipa)
  rescue SystemCallError
    raise Error, "Release build output is missing"
  end
end
