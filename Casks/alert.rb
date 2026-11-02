cask "alert" do
  version "0.1.0"
  sha256 "e75ebc507b96e991e75a709920327fddf72bd84a66e283c54a5b6c3cc0595195"

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
