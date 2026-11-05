# 浏览器
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myHome.gui.apps.browsers;
  guiCfg = config.myHome.gui;
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  options.myHome.gui.apps.browsers.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用浏览器应用";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    # Microsoft Edge — nixpkgs 的 microsoft-edge 是对官方 .deb 的重打包（unfree，
    # 仓库已在 modules/shared/nix.nix / modules/nixos/core/default.nix 全局
    # allowUnfree）。可执行文件名为 microsoft-edge-stable；niri 的
    # Mod+Shift+Return（浏览器）绑定指向它，见 niri/config/binds/apps.kdl。
    # Edge 若用「系统默认」外观（走 GTK/MacTahoe），窗口框是浏览器自绘的 ~14px
    # 圆角，独立于 GTK 主题 CSS、也独立于 niri；niri 的 geometry-corner-radius 只能
    # 裁剪、无法把这个更大的圆角缩小。把 Edge 设置里的外观从「系统默认」改成
    # 「浅色/深色」（本机 color-scheme 固定 prefer-light，故改成「浅色」无副作用）后，
    # Edge 改用它自己的方形窗口框，四角即与其它窗口一致。详见 docs/quirks.md。
    # 注：`--enable-features=...msForceNoRoundedCornerAndMargin` 实测无效，不要再用。
    home.packages = [
      pkgs.microsoft-edge
    ];

    # Edge「系统默认」外观会自绘 ~14px 圆角窗口框；改成「浅色」让它改用自带方形
    # 窗口框，四角随其它窗口统一。该偏好存在用户 profile 里，用 activation 幂等写入；
    # 若 Edge 正在运行则跳过（否则退出 Edge 时会把内存里的旧值写回、覆盖本次修改）。
    home.activation.edgeLightAppearance = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            prefs="$HOME/.config/microsoft-edge/Default/Preferences"
            if [ -f "$prefs" ]; then
              if pgrep -x msedge >/dev/null 2>&1; then
                echo "Edge 正在运行：跳过 Edge 外观偏好写入；完全退出 Edge 后重新 switch 即生效。" >&2
              else
                ${pkgs.python3}/bin/python3 - "$prefs" <<'PY'
      import json, sys, os, tempfile
      p = sys.argv[1]
      try:
          with open(p, encoding="utf-8") as f:
              d = json.load(f)
      except Exception:
          sys.exit(0)
      th = d.setdefault("extensions", {}).setdefault("theme", {})
      if th.get("system_theme") != 0:
          th["system_theme"] = 0
          d["extensions"]["theme"] = th
          fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p))
          with os.fdopen(fd, "w", encoding="utf-8") as f:
              json.dump(d, f, ensure_ascii=False)
          os.replace(tmp, p)
      PY
              fi
            fi
    '';

    # Brave 已于 2026-11-03 从 nixpkgs 移除（维护者缺失 + 安全问题，硬 throw），
    # 本仓库不再声明它的包与默认关联；Brave 改在 ~/Apps 自行维护（自带 desktop
    # entry，MIME 关联也由它自己「设为默认」，仓库不再钉）。故这里不再列 brave、
    # 不再设 BROWSER=brave。
    #
    # Zen browser — Firefox-based, from the community flake (beta channel).
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = false;
    };

  };
}
