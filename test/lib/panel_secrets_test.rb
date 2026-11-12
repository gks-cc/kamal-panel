require "test_helper"
require "panel_secrets"

class PanelSecretsTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    @warnings = []
  end

  teardown { FileUtils.rm_rf(@root) }

  def load!(env) = PanelSecrets.load!(root: @root, env:, warn: ->(message) { @warnings << message })
  def file = File.join(@root, PanelSecrets::FILE)

  test "a fresh install generates every missing secret once and reuses it on the next boot" do
    first = {}
    load!(first)

    assert_equal %w[SECRET_KEY_BASE AR_ENCRYPTION_PRIMARY_KEY AR_ENCRYPTION_DETERMINISTIC_KEY AR_ENCRYPTION_KEY_DERIVATION_SALT].sort,
                 first.keys.sort
    assert_equal "600", format("%o", File.stat(file).mode & 0o777)
    assert_match "same volume", @warnings.join

    second = {}
    load!(second)
    assert_equal first, second
  end

  test "set environment variables win and are never written to the file" do
    env = { "AR_ENCRYPTION_PRIMARY_KEY" => "from-env" }
    load!(env)

    assert_equal "from-env", env["AR_ENCRYPTION_PRIMARY_KEY"]
    assert_not_includes YAML.safe_load_file(file).keys, "AR_ENCRYPTION_PRIMARY_KEY"
  end

  test "leaves SECRET_KEY_BASE to the credentials when their key is provided" do
    env = { "RAILS_MASTER_KEY" => "x" }
    load!(env)

    assert_nil env["SECRET_KEY_BASE"]
  end

  test "does not invent encryption keys for a database that already holds data" do
    FileUtils.mkdir_p(File.dirname(File.join(@root, PanelSecrets::DATABASE)))
    FileUtils.touch(File.join(@root, PanelSecrets::DATABASE))
    env = {}
    load!(env)

    assert_nil env["AR_ENCRYPTION_PRIMARY_KEY"]
    assert env["SECRET_KEY_BASE"].present?, "sessions can start over; encrypted data can't"
    assert_match "original values", @warnings.join
  end

  test "generates nothing while the image is being built" do
    env = { "SECRET_KEY_BASE_DUMMY" => "1" }
    load!(env)

    assert_not File.exist?(file)
    assert_nil env["AR_ENCRYPTION_PRIMARY_KEY"]
  end
end
