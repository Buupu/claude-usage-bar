class ClaudeUsageBar < Formula
  desc "Real Claude usage in your macOS menu bar"
  homepage "https://github.com/Buupu/claude-usage-bar"
  url "https://github.com/Buupu/claude-usage-bar/archive/refs/tags/v1.0.3.tar.gz"
  sha256 "468cbba687fa47cf2b52b02968e48935b0bc8a48513054079242f4da29c9531c"
  license "MIT"
  head "https://github.com/Buupu/claude-usage-bar.git", branch: "main"

  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    # Ad-hoc sign with the hardened runtime: blocks DYLD_INSERT_LIBRARIES
    # injection, so nothing can piggyback on the app's Keychain "Always
    # Allow" grant to read the Claude Code token silently.
    system "codesign", "--force", "--sign", "-", "--options", "runtime",
           ".build/release/claude-usage-bar"
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
