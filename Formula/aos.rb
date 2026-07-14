class Aos < Formula
  desc "Modular Agent Operating System built on Astrid Runtime"
  homepage "https://aos.unicity.ai"
  version "2026.1.0"
  license "Apache-2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.0/unicity-aos-aarch64-apple-darwin.tar.gz"
      sha256 "bd449e0196743f34e8440077e8aae5ff41d4704021ab4954091cc8dae2314662"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.0/unicity-aos-x86_64-apple-darwin.tar.gz"
      sha256 "e0576ad78cbeaadf06934ab24b85776c9078774b3d359d8da23620a079a3de02"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.0/unicity-aos-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "a65bafbd199822d4f92c2e05be872e09d94ddee090f431b65bcff96816dc4fe2"
    else
      url "https://github.com/unicity-aos/aos-ce/releases/download/2026.1.0/unicity-aos-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "a4e89b9bf8d40b5d00d028ddaabedcaf42840e6b97f30bb880a43e1df2c37aec"
    end
  end

  def install
    libexec.install "bin", "runtime", "Distro.toml", "release-manifest.json", "runtime-compatibility.toml"
    (bin/"aos").write_env_script libexec/"bin/aos",
      "UNICITY_AOS_RUNTIME_BIN" => libexec/"runtime/bin/astrid",
      "UNICITY_AOS_INSTALL_METHOD" => "homebrew"
  end

  test do
    assert_match "Unicity AOS 2026.1.0", shell_output("#{bin}/aos --version")
    assert_predicate libexec/"runtime/bin/astrid", :executable?
    assert_predicate libexec/"runtime/bin/astrid-daemon", :executable?
  end
end
