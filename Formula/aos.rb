class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.1/unicity-aos-2026.1.1-aarch64-apple-darwin.tar.gz"
      sha256 "256043e3450f80c623aa333816618cb8f9913b211b99c888869f60aa0436c2d7"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.1/unicity-aos-2026.1.1-x86_64-apple-darwin.tar.gz"
      sha256 "a8d547e8cd54d5d0eb5b4375b75cf72d343dd81eea75ca60f494cde4bfab1359"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.1/unicity-aos-2026.1.1-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "b65d7cf13b6b4a9fca4dd4e966be3ba2d2492ada6e84a392a2e4cdf731c90b61"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.1/unicity-aos-2026.1.1-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "8198e841cd469aa7e3eba000d5cb7410d0a36d6ed80e7c4bb49c08b0960dd4cd"
    end
  end

  def install
    libexec.install "bin", "runtime", "capsules", "capsule-assets.txt",
                    "Distro.toml", "release-manifest.json", "runtime-compatibility.toml"
    (bin/"aos").write_env_script libexec/"bin/aos",
      "UNICITY_AOS_RUNTIME_BIN"    => libexec/"runtime/bin/astrid",
      "UNICITY_AOS_CAPSULE_DIR"    => libexec/"capsules",
      "UNICITY_AOS_INSTALL_METHOD" => "homebrew"
  end

  test do
    ENV["HOME"] = testpath/"user"
    ENV["AOS_HOME"] = testpath/"home"
    assert_match "Unicity AOS 2026.1.1", shell_output("#{bin}/aos --version")
    assert_predicate libexec/"runtime/bin/astrid", :executable?
    assert_predicate libexec/"runtime/bin/astrid-daemon", :executable?
    begin
      system bin/"aos", "init", "--offline", "--yes", "--var",
             "openai_api_key=homebrew-test-placeholder"
      assert_predicate testpath/"home/distributions/unicity-ce/Distro.toml", :file?
      assert_predicate testpath/"home/runtime/home/default/.config/distro.lock", :file?
    ensure
      system bin/"aos", "stop"
    end
  end
end
