class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.0/unicity-aos-2026.10.0-aarch64-apple-darwin.tar.gz"
      sha256 "91f2883fd31f24369a788fa9d5b18b0545f89ae33a21659af842daefc32d0dfa"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.0/unicity-aos-2026.10.0-x86_64-apple-darwin.tar.gz"
      sha256 "fa0197b95ce8940f302b936f1e4de6e0c69cb930a744913214ac10ff00a491a7"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.0/unicity-aos-2026.10.0-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "cd5b5cd520ec42ab96f8f9f7948d6ca1fb2c4e94a60b443f390dbd0ec86c7be5"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.10.0/unicity-aos-2026.10.0-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "19b459fcbc2c68be43d085c2ce8a365c29423cb5585bffde3e4add0348c43349"
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
    assert_match "Unicity AOS 2026.10.0", shell_output("#{bin}/aos --version")
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
