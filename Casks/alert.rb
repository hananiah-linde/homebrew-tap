cask "alert" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/hananiah-linde/alert/releases/download/v#{version}/Alert-#{version}.zip"
  name "Alert"
  desc "Menu bar utility that shows Dock badges for chosen apps"
  homepage "https://github.com/hananiah-linde/alert"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Alert.app"

  uninstall quit: "io.github.hananiah-linde.alert"
end
