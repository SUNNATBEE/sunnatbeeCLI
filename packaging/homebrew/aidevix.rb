# Homebrew formula — Aidevix CLI
#
# Bu faylni o'z tap'ingizga joylang (masalan `homebrew-tap` repozitoriyasi):
#   SUNNATBEE/homebrew-tap/Formula/aidevix.rb
# So'ng foydalanuvchilar shunday o'rnatadi:
#   brew install SUNNATBEE/tap/aidevix
#
# Yangi reliz chiqarganda yangilash:
#   1) `url` dagi tegni (vX.Y.Z) yangilang.
#   2) `sha256` ni hisoblang:
#        curl -fsSL <url> | shasum -a 256
#      va quyiga qo'ying.
class Aidevix < Formula
  desc "One command, 37+ top AI CLIs — interactive launcher for terminal AI agents"
  homepage "https://github.com/SUNNATBEE/sunnatbeeCLI"
  url "https://github.com/SUNNATBEE/sunnatbeeCLI/archive/refs/tags/v1.11.0.tar.gz"
  sha256 "f86c6259fb77a45b132677571c76165dcf3495cd34a57fb0b8cd29d54a22a571"
  license "MIT"
  head "https://github.com/SUNNATBEE/sunnatbeeCLI.git", branch: "main"

  depends_on "bash"
  # fzf majburiy emas, lekin u bilan menyu ancha chiroyli (izlanadigan, preview'li).
  depends_on "fzf" => :recommended

  def install
    # Yadro fayllarni libexec ichiga ko'chiramiz; bin'ga ozg'in wrapper qo'yamiz.
    libexec.install "bin", "lib", "config", "completions", "VERSION"

    (bin/"aidevix").write <<~SH
      #!/usr/bin/env bash
      exec "#{Formula["bash"].opt_bin}/bash" "#{libexec}/bin/ai-selector.sh" "$@"
    SH

    # Bash completion (zsh ham bashcompinit orqali ishlatadi).
    bash_completion.install "completions/aidevix.bash" => "aidevix"
    # Fish/zsh native completion (mavjud bo'lsa).
    fish_completion.install "completions/aidevix.fish" if File.exist?("completions/aidevix.fish")
    zsh_completion.install "completions/_aidevix" if File.exist?("completions/_aidevix")
  end

  test do
    assert_match "Aidevix CLI", shell_output("#{bin}/aidevix --version")
  end
end
