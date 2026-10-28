# Nautilus（GNOME Files）集成
#
# 目的：右键在目标目录直接开终端。
#
# 为什么不用 Nautilus 自带入口：Nautilus 50 已经删掉了通用的「在终端中打开」——
# 剩下的 `view.run-in-terminal` 只对「可执行文本文件」生效（是把这个脚本丢进终端跑，
# 不是在该目录开 shell），而唯一针对文件夹的 `view.console` /
# `view.current-directory-console` 在上游是硬编码走 D-Bus 的 `org.gnome.Console`
# （nautilus-dbus-launcher.c），本机没装 GNOME Console，Ghostty 也不实现
# 那套接口，所以自带入口一个都用不上。
#
# 改用 Nautilus 的**脚本**机制：可执行脚本放进 ~/.local/share/nautilus/scripts/，
# 右键菜单的「脚本」子菜单里就会出现它（nautilus-scripts-monitor.c 扫该目录）。
# 脚本的标题就是它的文件名，所以这里直接用中文命名。
#
# 脚本的执行约定（上游 nautilus-files-view.c）：
#   - 工作目录 = 当前视图目录（run_script 先 chdir 再启动脚本）；
#   - argv[1..] = 选中项**相对当前视图目录**的路径（get_file_names_as_parameter_array）；
#   - 在空白处右键（没有选中项）时没有参数，此时用工作目录本身。
#
# 注意：脚本正文里的 shell 变量展开在 Nix 字符串中要写成两个单引号开头的转义形式
# （即 ''$ 加花括号），否则会被 Nix 当成插值解析报错。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.myHome.gui.apps.nautilus;
  guiCfg = config.myHome.gui;
in
{
  options.myHome.gui.apps.nautilus.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Nautilus（GNOME Files）及其右键开终端集成";
  };

  config = lib.mkIf (cfg.enable && guiCfg.enable) {
    home.packages = [ pkgs.nautilus ];

    xdg.dataFile."nautilus/scripts/在 Ghostty 中打开" = {
      # Nautilus 只列出可执行的脚本（靠 nautilus_file_should_show 过滤隐藏文件，
      # 真正能不能跑取决于执行位），故必须显式打开。
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # 在当前视图目录、或选中项所在目录打开 Ghostty。
        #
        # 由 Nautilus 调起：工作目录已是当前视图目录，选中项以相对路径作参数传入；
        # 空白处右键（没有选中项）时没有参数，此时用工作目录本身。多选时只用第一项。
        set -euo pipefail

        target="''${1:-$PWD}"

        # 参数是相对当前视图目录的路径，补成绝对路径
        if [[ "$target" != /* ]]; then
          target="$PWD/$target"
        fi

        # 选中的是文件时，开在它所在的目录
        if [[ -f "$target" ]]; then
          dir="''${target%/*}"
          target="''${dir:-/}"
        fi

        # 绝对路径而非 PATH 查找：与 programs.ghostty 装的是同一个 ghostty
        # （store 路径随 rebuild 自动更新），也不依赖 Nautilus 继承到的 PATH。
        exec ${pkgs.ghostty}/bin/ghostty --working-directory="$target"
      '';
    };
  };
}
