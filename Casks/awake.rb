cask "awake" do
  version "0.1.1"
  sha256 "97424b52cdb56fd3c0e1faba5bcfc58f39fa4bca242d1d608a0ee97c05141b00"

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
