class ClaudeUsageBar < Formula
  desc "Real Claude usage in your macOS menu bar"
  homepage "https://github.com/Buupu/claude-usage-bar"
  url "https://github.com/Buupu/claude-usage-bar/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "afe76590dcd27428fd54ea86b5675bde71b76c17a9ff1076820f675f9a467d04"
  license "MIT"
  head "https://github.com/Buupu/claude-usage-bar.git", branch: "main"

  depends_on :macos
  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/claude-usage-bar"
  end

  service do
    run [opt_bin/"claude-usage-bar"]
    keep_alive true
    log_path var/"log/claude-usage-bar.log"
    error_log_path var/"log/claude-usage-bar.log"
  end

  def caveats
    <<~EOS
      Requires Claude Code to be installed and signed in (the app reads its
      OAuth token from the Keychain — click "Always Allow" on first run).

      To start now and at every login:
        brew services start claude-usage-bar
    EOS
  end

  test do
    assert_path_exists bin/"claude-usage-bar"
  end
end
