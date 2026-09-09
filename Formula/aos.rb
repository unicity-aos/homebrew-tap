class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.0/unicity-aos-2026.9.0-aarch64-apple-darwin.tar.gz"
      sha256 "46378c58687d58a23ce3ee5de64c855c624ee576a0a1296c750e5e5dfeba5f18"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.0/unicity-aos-2026.9.0-x86_64-apple-darwin.tar.gz"
      sha256 "089fd52ff20f42b7da2343d8f37812a05cdfb2158860461f8406f80e27d86ae1"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.0/unicity-aos-2026.9.0-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "029f8beae6b7d9820e733bd59120da1578c40ac9be3b2158ed3497c8b9da2ae3"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.0/unicity-aos-2026.9.0-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "f2fab771d69a11000d661c63a13597f3371ac115514753d1466f5ef97dee2b54"
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
    assert_match "Unicity AOS 2026.9.0", shell_output("#{bin}/aos --version")
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
