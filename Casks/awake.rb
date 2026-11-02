cask "awake" do
  version "0.1.0"
  sha256 "add503a24dc2ce71e216b5a66dfb9ed0bf5477b4f497d9f92377d0052c051960"

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
