# frozen_string_literal: true

require "minitest/autorun"
require "yaml"
require_relative "../lib/backend_release_guard"
require_relative "../redact_release_logs"

class BackendReleaseGuardTest < Minitest::Test
  Guard = BackendReleaseGuard
  REF = "abcdefghijklmnopqrst"
  KEY = "sb_publishable_fixture_client_key"
  ROOT = File.expand_path("../..", __dir__)
  Response = Struct.new(:code, :body)

  def setup
    @env = {
      "KUMPUL_PRODUCTION_PROJECT_REF" => REF,
      "KUMPUL_PRODUCTION_BACKEND_URL" => "https://#{REF}.supabase.co",
      "KUMPUL_PRODUCTION_PUBLISHABLE_KEY" => KEY
    }
    @expected = Guard.expected("beta", @env)
  end

  def assert_rejected(env)
    error = assert_raises(Guard::Error) { Guard.expected("beta", env) }
    refute_includes error.message, KEY
    refute_includes error.message, @expected.url
  end

  def legacy_key(role: "anon", ref: REF)
    [Base64.urlsafe_encode64('{"alg":"HS256"}', padding: false),
     Base64.urlsafe_encode64(JSON.generate(role: role, ref: ref), padding: false), "fixture_signature"].join(".")
  end

  def test_accepts_modern_publishable_key
    assert_equal "production", @expected.environment
    assert_equal "Release", @expected.configuration
    assert @expected.frozen?
  end

  def test_accepts_legacy_anon_key
    assert Guard.expected("beta", @env.merge("KUMPUL_PRODUCTION_PUBLISHABLE_KEY" => legacy_key))
  end

  def test_missing_inputs_are_rejected
    @env.keys.each { |name| assert_rejected(@env.reject { |key, _| key == name }) }
  end

  def test_empty_whitespace_and_placeholders_are_rejected
    ["", " ", "replace-with-production-publishable-key", "$(UNRESOLVED)", "publishable-test-key"].each do |key|
      assert_rejected(@env.merge("KUMPUL_PRODUCTION_PUBLISHABLE_KEY" => key))
    end
  end

  def test_invalid_example_and_insecure_hosts_are_rejected
    ["https://production.invalid", "https://staging.example.invalid",
     "https://replace-with-production-project.supabase.co", "http://#{REF}.supabase.co",
     "https://anotherprojectrefhere.supabase.co", "https://127.0.0.1", "$(BACKEND_URL)"].each do |url|
      assert_rejected(@env.merge("KUMPUL_PRODUCTION_BACKEND_URL" => url))
    end
  end

  def test_url_credentials_paths_queries_and_fragments_are_rejected
    ["https://user:pass@#{REF}.supabase.co", "#{@expected.url}/", "#{@expected.url}/functions/v1",
     "#{@expected.url}?key=a", "#{@expected.url}#fragment", "#{@expected.url}:444"].each do |url|
      assert_rejected(@env.merge("KUMPUL_PRODUCTION_BACKEND_URL" => url))
    end
  end

  def test_server_keys_and_wrong_project_legacy_keys_are_rejected
    ["sb_secret_fixture", legacy_key(role: "service_role"), legacy_key(ref: "otherprojectrefhereaa")].each do |key|
      assert_rejected(@env.merge("KUMPUL_PRODUCTION_PUBLISHABLE_KEY" => key))
    end
  end

  def test_malformed_legacy_keys_are_rejected
    ["a.invalid.signature", "a.#{Base64.urlsafe_encode64('null')}.c"].each do |key|
      assert_rejected(@env.merge("KUMPUL_PRODUCTION_PUBLISHABLE_KEY" => key))
    end
  end

  def test_staging_lane_is_pinned_to_reset_project
    env = {
      "KUMPUL_STAGING_PROJECT_REF" => Guard::STAGING_REF,
      "KUMPUL_STAGING_BACKEND_URL" => "https://#{Guard::STAGING_REF}.supabase.co",
      "KUMPUL_STAGING_PUBLISHABLE_KEY" => KEY
    }
    assert_equal "Staging", Guard.expected("staging_beta", env).configuration
    assert_raises(Guard::Error) { Guard.expected("staging_beta", env.merge("KUMPUL_STAGING_PROJECT_REF" => REF)) }
    assert_rejected(@env.merge("KUMPUL_PRODUCTION_PROJECT_REF" => Guard::STAGING_REF))
  end

  def test_unknown_lanes_are_rejected
    assert_raises(Guard::Error) { Guard.expected("release", @env) }
  end

  def test_gateway_health_verifies_key_without_writes
    transport = lambda do |uri, request|
      assert_equal "/auth/v1/health", uri.path
      assert_equal "GET", request.method
      assert_equal KEY, request["apikey"]
      assert_nil request["Authorization"]
      Response.new("200", '{"name":"GoTrue","version":"v2.fixture"}')
    end
    assert Guard.verify_backend(@expected, transport: transport)
  end

  def test_gateway_rejection_redirect_and_bad_health_block_release
    [Response.new("401", '{}'), Response.new("302", '{}'), Response.new("503", '{}'),
     Response.new("200", '{}'), Response.new("200", 'not-json')].each do |response|
      assert_raises(Guard::Error) { Guard.verify_backend(@expected, transport: ->(*) { response }) }
    end
  end

  def test_network_errors_are_redacted
    error = assert_raises(Guard::Error) do
      Guard.verify_backend(@expected, transport: ->(*) { raise "connection #{KEY}" })
    end
    refute_includes error.message, KEY
  end

  def test_xcconfig_is_private_selected_and_escaped
    Dir.mktmpdir do |directory|
      path = File.join(directory, "Secrets.xcconfig")
      Guard.write_xcconfig(@expected, path)
      text = File.read(path)
      assert_includes text, "https:/$()/#{REF}.supabase.co"
      assert_includes text, "KUMPUL_PRODUCTION_PUBLISHABLE_KEY = #{KEY}"
      refute_includes text, "KUMPUL_STAGING"
      assert_equal 0o600, File.stat(path).mode & 0o777
      assert_raises(Guard::Error) { Guard.write_xcconfig(@expected, path) }
      assert_equal text, File.read(path)
    end
  end

  def test_build_number_cannot_inject_shell_or_build_arguments
    [nil, "", "1 OTHER=1", "1;touch /tmp/file", "$(cmd)", "2\n3"].each do |number|
      assert_raises(Guard::Error) { Guard.build_number(number) }
    end
    assert_equal "123", Guard.build_number("123")
  end

  def plist
    {
      "KumpulBackendEnvironment" => "production", "KumpulBackendURL" => @expected.url,
      "KumpulBackendPublishableKey" => KEY, "CFBundleIdentifier" => @expected.bundle_id,
      "CFBundleVersion" => "123"
    }
  end

  def settings
    {
      "KUMPUL_BACKEND_ENVIRONMENT" => "production", "KUMPUL_BACKEND_URL" => @expected.url,
      "KUMPUL_BACKEND_PUBLISHABLE_KEY" => KEY, "PRODUCT_BUNDLE_IDENTIFIER" => @expected.bundle_id,
      "CURRENT_PROJECT_VERSION" => "123"
    }
  end

  def test_effective_build_settings_are_checked_for_main_target
    executor = lambda do |*args, **options|
      assert_includes args, "Release"
      assert_includes args, "CURRENT_PROJECT_VERSION=123"
      assert_equal ROOT, options[:chdir]
      [JSON.generate([{ "target" => "happyFamily", "buildSettings" => settings }]), "",
       Struct.new(:success?).new(true)]
    end
    assert Guard.verify_build_settings(@expected, "123", root: ROOT, executor: executor)
  end

  def test_unexpected_or_duplicate_build_targets_are_rejected
    [[], [{ "target" => "happyFamilyPersonal" }],
     [{ "target" => "happyFamily" }, { "target" => "happyFamily" }]].each do |targets|
      executor = ->(*) { [JSON.generate(targets), "", Struct.new(:success?).new(true)] }
      assert_raises(Guard::Error) { Guard.verify_build_settings(@expected, "123", root: ROOT, executor: executor) }
    end
  end

  def write_plist(path, values)
    FileUtils.mkdir_p(File.dirname(path))
    _stdout, stderr, status = Open3.capture3("python3", "-c",
      "import json,plistlib,sys; plistlib.dump(json.load(sys.stdin),open(sys.argv[1],'wb'),fmt=plistlib.FMT_BINARY)",
      path, stdin_data: JSON.generate(values))
    assert status.success?, stderr
  end

  def with_artifacts
    Dir.mktmpdir do |output|
      archive = File.join(output, "happyFamily.xcarchive")
      archive_plist = File.join(archive, "Products/Applications/happyFamily.app/Info.plist")
      package = File.join(output, "package")
      ipa_plist = File.join(package, "Payload/happyFamily.app/Info.plist")
      write_plist(archive_plist, plist)
      write_plist(ipa_plist, plist)
      ipa = File.join(output, "happyFamily.ipa")
      repack = lambda do
        FileUtils.rm_f(ipa)
        _stdout, stderr, status = Open3.capture3("zip", "-qr", ipa, "Payload", chdir: package)
        assert status.success?, stderr
      end
      repack.call
      yield output, archive, ipa, archive_plist, ipa_plist, repack
    end
  end

  def assert_upload_blocked(output, archive, ipa)
    uploaded = false
    assert_raises(Guard::Error) do
      Guard.upload_validated(archive: archive, ipa: ipa, expected: @expected, number: "123", output_directory: output) do
        uploaded = true
      end
    end
    refute uploaded, "Uploader must never be called with an invalid artifact"
  end

  def test_valid_archive_and_ipa_reach_explicit_uploader
    with_artifacts do |output, archive, ipa, *_rest|
      uploaded = nil
      Guard.upload_validated(archive: archive, ipa: ipa, expected: @expected, number: "123", output_directory: output) do |path|
        uploaded = path
      end
      assert_equal File.realpath(ipa), uploaded
    end
  end

  def test_every_archive_field_is_required_before_upload
    plist.keys.each do |field|
      with_artifacts do |output, archive, ipa, archive_plist, *_rest|
        write_plist(archive_plist, plist.merge(field => "wrong-or-unresolved"))
        assert_upload_blocked(output, archive, ipa)
      end
    end
  end

  def test_every_ipa_field_is_required_before_upload
    plist.keys.each do |field|
      with_artifacts do |output, archive, ipa, _archive_plist, ipa_plist, repack|
        write_plist(ipa_plist, plist.merge(field => "wrong-or-unresolved"))
        repack.call
        assert_upload_blocked(output, archive, ipa)
      end
    end
  end

  def test_missing_and_unreadable_archive_plists_block_upload
    with_artifacts do |output, archive, ipa, archive_plist, *_rest|
      FileUtils.rm_f(archive_plist)
      assert_upload_blocked(output, archive, ipa)
      File.write(archive_plist, "unreadable")
      assert_upload_blocked(output, archive, ipa)
    end
  end

  def test_missing_or_corrupt_ipa_blocks_upload
    with_artifacts do |output, archive, ipa, *_rest|
      FileUtils.rm_f(ipa)
      assert_upload_blocked(output, archive, ipa)
      File.write(ipa, "not a zip")
      assert_upload_blocked(output, archive, ipa)
    end
  end

  def test_missing_and_unreadable_ipa_plists_block_upload
    with_artifacts do |output, archive, ipa, _archive_plist, ipa_plist, repack|
      FileUtils.rm_f(ipa_plist)
      repack.call
      assert_upload_blocked(output, archive, ipa)
      File.write(ipa_plist, "unreadable")
      repack.call
      assert_upload_blocked(output, archive, ipa)
    end
  end

  def test_old_build_and_unrelated_output_block_upload
    with_artifacts do |output, archive, ipa, archive_plist, *_rest|
      write_plist(archive_plist, plist.merge("CFBundleVersion" => "122"))
      assert_upload_blocked(output, archive, ipa)
      write_plist(archive_plist, plist)
      Dir.mktmpdir do |other_output|
        assert_upload_blocked(other_output, archive, ipa)
      end
    end
  end

  def test_duplicate_applications_block_upload
    with_artifacts do |output, archive, ipa, archive_plist, *_rest|
      write_plist(File.join(File.dirname(File.dirname(archive_plist)), "Other.app/Info.plist"), plist)
      assert_upload_blocked(output, archive, ipa)
    end
  end

  def test_workflow_preflight_precedes_signing_and_staging_reset
    workflow = YAML.load_file(File.join(ROOT, ".github/workflows/testflight.yml"))
    steps = workflow.fetch("jobs").fetch("deploy").fetch("steps")
    names = steps.map { |step| step["name"] }
    preflight = names.index("Validate backend and create temporary configuration")
    assert_operator preflight, :<, names.index("Setup App Store Connect API Key")
    assert_operator preflight, :<, names.index("Reset kumpul-staging data before Staging TestFlight build")
    reset = steps.find { |step| step["name"] == "Reset kumpul-staging data before Staging TestFlight build" }
    assert_equal "github.event_name == 'workflow_dispatch' && github.event.inputs.lane == 'staging_beta'", reset["if"]
    cleanup = steps.find { |step| step["name"] == "Remove temporary configuration and API key" }
    assert_equal "always()", cleanup["if"]
    upload = steps.find { |step| step["uses"] == "actions/upload-artifact@v4" }
    assert_includes upload["with"]["path"], "redacted-fastlane-logs"
  end

  def test_failure_log_redaction_removes_client_and_server_material
    sensitive = [KEY, "sb_secret_fixture", legacy_key(role: "service_role"),
                 "fixture-password", @expected.url, @expected.url.sub("https://", "https:/$()/"),
                 "-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----"]
    env = @env.merge("SIGNING_PASSWORD" => "fixture-password")
    redacted = ReleaseLogRedaction.redact("Build failed\n#{sensitive.join("\n")}", env)
    assert_includes redacted, "Build failed"
    sensitive.each { |value| refute_includes redacted, value }
  end
end
