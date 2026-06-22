{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ytsurf-downloader;
  inherit (lib) mkEnableOption mkOption types;
in {
  options.programs.ytsurf-downloader = {
    enable = mkEnableOption "ytsurf-downloader — search, watch, or download YouTube videos";

    package = mkOption {
      type = types.package;
      default = pkgs.ytsurf-downloader;
      defaultText = lib.literalExpression "pkgs.ytsurf-downloader";
      description = "ytsurf-downloader package to use. Requires the flake overlay or manual assignment.";
    };

    downloadDir = mkOption {
      type = types.str;
      default = "$HOME/Downloads";
      example = "$HOME/Videos/YouTube";
      description = "Default download directory.";
    };

    convertTo = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "opus";
      description = ''
        Download and convert to this audio format via ffmpeg.
        Implies audio-only mode (opus, mp3, flac, m4a, etc.).
      '';
    };

    audioOnly = mkOption {
      type = types.bool;
      default = false;
      description = "Download audio only.";
    };

    downloadMode = mkOption {
      type = types.bool;
      default = false;
      description = "Default to download instead of play.";
    };

    formatSelection = mkOption {
      type = types.bool;
      default = false;
      description = "Enable interactive format/resolution selection.";
    };

    limit = mkOption {
      type = types.int;
      default = 15;
      description = "Number of search results to show.";
    };

    notify = mkOption {
      type = types.bool;
      default = true;
      description = "Show desktop notifications (requires notify-send).";
    };

    debugMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."ytsurf-downloader/config".text = ''
      download_dir="${cfg.downloadDir}"
      convert_to="${if cfg.convertTo != null then cfg.convertTo else ""}"
      audio_only=${lib.boolToString cfg.audioOnly}
      download_mode=${lib.boolToString cfg.downloadMode}
      format_selection=${lib.boolToString cfg.formatSelection}
      limit=${toString cfg.limit}
      notify=${lib.boolToString cfg.notify}
      debug_mode=${lib.boolToString cfg.debugMode}
    '';
  };
}
