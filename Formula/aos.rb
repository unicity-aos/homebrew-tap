class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.3/unicity-aos-2026.9.3-aarch64-apple-darwin.tar.gz"
      sha256 "05220fff8d4068102c516d3e1faa902dbb396639614fd89b19e02c8abc0e6acb"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.3/unicity-aos-2026.9.3-x86_64-apple-darwin.tar.gz"
      sha256 "0234549255857043b70ab239a397d7598f4c422f418d71aad78f60b31e565386"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.3/unicity-aos-2026.9.3-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "6959cf04d7706d5563665ac54d0e6bd40788b5c4a1b6aebf139a43a9dc2b75ba"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.9.3/unicity-aos-2026.9.3-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "ebe3e3974dbc730e23f98e6f680f7b8e2db886be855e5f4fdc2ad25a662bbe9c"
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
    assert_match "Unicity AOS 2026.9.3", shell_output("#{bin}/aos --version")
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
