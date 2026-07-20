class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.3/unicity-aos-2026.1.3-aarch64-apple-darwin.tar.gz"
      sha256 "a225cd2453c40adcf12e03edd026e9b2165dab845c5cb972e26874780e7c8665"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.3/unicity-aos-2026.1.3-x86_64-apple-darwin.tar.gz"
      sha256 "f9baf841a4edcf68578a725ca0e39852915cf4c4b68d3e04f7439a661c0a2b46"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.3/unicity-aos-2026.1.3-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "bff561375179d3289b3d3e2ef90f804c9841b32003870683acc0b100078db6ad"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.3/unicity-aos-2026.1.3-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "cf2079df871016ce608ca1b8f290912dc002e550ae8d4c6795d3d33324e29c8e"
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
    assert_match "Unicity AOS 2026.1.3", shell_output("#{bin}/aos --version")
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
