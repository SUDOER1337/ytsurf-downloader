{
  curl,
  ffmpeg,
  fzf,
  jq,
  lib,
  makeWrapper,
  mpv,
  perl,
  stdenvNoCC,
  yt-dlp,
}:
stdenvNoCC.mkDerivation {
  pname = "ytsurf-downloader";
  version = "1.0.0";

  nativeBuildInputs = [makeWrapper];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm777 ${./ytsurf.sh} $out/bin/ytsurf-downloader
    wrapProgram $out/bin/ytsurf-downloader \
      --prefix PATH : ${
      lib.makeBinPath [
        curl
        ffmpeg
        fzf
        jq
        mpv
        perl
        yt-dlp
      ]
    }

    runHook postInstall
  '';

  meta.mainProgram = "ytsurf-downloader";
}
