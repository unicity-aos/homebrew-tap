class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.2/unicity-aos-2026.9.2-aarch64-apple-darwin.tar.gz"
      sha256 "32b9e4f8f56266060e2ff5dd820f4c2ff893544343ab8bf2d9c25bbe82a7379c"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.2/unicity-aos-2026.9.2-x86_64-apple-darwin.tar.gz"
      sha256 "60b9742a9aff8b129bdc5dbaaf5fb9abe3eef3e25646c8ffbb8c8bd478b780be"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.2/unicity-aos-2026.9.2-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "57545559196161319203ab8382cbd8a4f2a6bc8d0a7f7bb9317471e013fbc320"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.2/unicity-aos-2026.9.2-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "ef6e8de107741bd835b91bdc45ce7d27bd738523271e76d7a068f8bd58909598"
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
    assert_match "Unicity AOS 2026.9.2", shell_output("#{bin}/aos --version")
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
