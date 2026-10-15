class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.1/unicity-aos-2026.10.1-aarch64-apple-darwin.tar.gz"
      sha256 "4fdced38acd51526c41ec7c8dac86ee0caad6521477caadcf80d22f63a43cad7"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.1/unicity-aos-2026.10.1-x86_64-apple-darwin.tar.gz"
      sha256 "3a15a0c7040445a720b810dc626e550b5f11c4b7603d067f918a7f53c521aa8c"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.1/unicity-aos-2026.10.1-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "4040d37b2c96d09d88fa0fadfd97d7af5430147349d51f1014c9aab4aa594e8b"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.1/unicity-aos-2026.10.1-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "63d8fba4d9ca8d9eb8a83f68f653ebe3100aeb070cbc8f73e3a85646219c90fc"
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
    assert_match "Unicity AOS 2026.10.1", shell_output("#{bin}/aos --version")
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
