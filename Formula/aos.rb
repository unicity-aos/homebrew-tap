class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.1/unicity-aos-2026.9.1-aarch64-apple-darwin.tar.gz"
      sha256 "7cab03cca13ac88774411ec2aa18da8f2da131b963d4d123dd990d17ce71549e"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.1/unicity-aos-2026.9.1-x86_64-apple-darwin.tar.gz"
      sha256 "bd94793f0dd4e3991b09538fc99844fa33d87e00882ec8377c655b276e7e4567"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.1/unicity-aos-2026.9.1-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "65c64d71fc2762eae5d5a39bea146f9707528b37d4d2fe2168351d2f6c10d834"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.1/unicity-aos-2026.9.1-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "5bd9d19899d47fab945bbe236a6803b2499e79f50f480a50b87fbed0e9448561"
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
    assert_match "Unicity AOS 2026.9.1", shell_output("#{bin}/aos --version")
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
