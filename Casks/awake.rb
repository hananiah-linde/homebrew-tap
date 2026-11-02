cask "awake" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/hananiah-linde/awake/releases/download/v#{version}/Awake-#{version}.zip"
  name "Awake"
  desc "Menu bar utility that prevents sleep"
  homepage "https://github.com/hananiah-linde/awake"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Awake.app"

  uninstall quit: "io.github.hananiah-linde.awake"
end
