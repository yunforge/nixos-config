# PipeWire 音频服务
{ lib, config, ... }:
let
  cfg = config.mySystem.hardware;
in
{
  options.mySystem.hardware.audio.enable = lib.mkEnableOption "PipeWire 音频服务";

  config = lib.mkIf (cfg.enable && cfg.audio.enable) {
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
    };

    # 蓝牙只提供 A2DP 与 LE Audio(BAP) 角色，去掉经典 HSP/HFP 全家（含耳机麦克风）：
    # FreeBuds 6i 连接期间 HFP("Hands-Free Voice gateway")信道每 3s 建断、从未成功建立
    # （3 天 1262 条 err，伴生 A2DP SEP 缓存警告与 WirePlumber 节点创建重试风暴）。
    # 需要耳机麦克风时删掉此段（roles 回落上游默认）即可，详见 docs/quirks.md。
    services.pipewire.wireplumber.extraConfig."95-bluetooth-a2dp-only" = {
      "monitor.bluez.properties" = {
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
          "bap_sink"
          "bap_source"
        ];
        "bluez5.auto-connect" = [ "a2dp_sink" ];
      };
    };
  };
}
