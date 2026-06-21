class YtsurfDownloader < Formula
  desc "Search, watch, or download YouTube videos from your terminal"
  homepage ""
  url "https://github.com/<your-org>/ytsurf-downloader/archive/refs/tags/v1.0.0.zip"
  sha256 ""
  version "1.0.0"
  license "GPL-3.0"

  depends_on "bash"
  depends_on "yt-dlp"
  depends_on "jq"
  depends_on "curl"
  depends_on "mpv"
  depends_on "perl"
  depends_on "fzf"
  depends_on "ffmpeg"

  def install
    system "mv ytsurf.sh ytsurf-downloader"
    bin.install "ytsurf-downloader"
  end

  test do
    system "ytsurf-downloader"
  end
end
