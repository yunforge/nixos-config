# Home Manager 用户层入口（所有主机的公共底座）
#
# 分层（详见 docs/architecture.md）：
#   common/   跨平台公共配置（shell / 编辑器 / CLI·TUI 工具）
#   dev/      语言工具链（与普通 CLI 分离：是否安装完整工具链由角色决定）
#   gui/      GUI 应用与 Linux 桌面会话
#             - apps/shared/   跨平台 GUI 应用配置（ghostty / vscode）
#             - apps/linux/    Linux 专属 GUI 应用
#             - desktop/linux/ Linux 桌面会话（niri / noctalia / 主题 / 输入法）
#   platform/ 平台专属适配（linux / darwin）
#   profiles/ 角色配置：决定某类设备需要哪些能力
#             （workstation / server / wsl / macbook，由各主机经 flake.nix 导入）
#
# 本文件只做两件事：定义公共选项（mengw.cli / mengw.gui / 主题切换登记表），
# 以及导入所有主机共享的 common 层。dev 与 gui 层由各角色 profile 组合，
# 不在这里无条件导入——服务器/WSL 不应被动继承工作站能力。
{
  config,
  lib,
  ...
}:
{
  options.mengw.cli.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 CLI/TUI 用户环境（shell、编辑器、CLI 工具）";
  };

  options.mengw.dev.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用语言工具链（Go / Node / Rust / Python / C++ 等）";
  };

  options.mengw.gui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 GUI 用户配置（跨平台 GUI 应用与平台专属应用）";
  };

  options.mengw.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "启用 Linux 桌面会话（Niri / Noctalia / 主题 / 输入法）";
  };

  options.mengw.appearance.switchTargets = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          live = lib.mkOption {
            type = lib.types.str;
            description = "应用真正读的那个文件，相对 $HOME（如 .config/gtk-4.0/settings.ini）";
          };
          dark = lib.mkOption {
            type = lib.types.str;
            description = "暗色变体，相对 $HOME（如 theme-variants/gtk-3.0/dark.ini）";
          };
          light = lib.mkOption {
            type = lib.types.str;
            description = "亮色变体，相对 $HOME";
          };
        };
      }
    );
    default = [ ];
    description = ''
      亮/暗切换时要翻的软链。真源是 Noctalia 的 theme mode，执行者是
      gui/desktop/linux/themes/variants.nix 里的 theme-apply：它只做「live 指到当前
      模式的变体」这件事，各层（GTK/Qt/niri、btop…）把自己的两个变体生成到 store
      并在这里登记。
      登记者自己负责让 live 文件首次存在（HM 初始值 = 暗色）；rebuild 会把 live 还原成
      暗色，登录时的 theme-apply 再按 Noctalia 的 mode 纠正，不需要额外的状态文件。
    '';
  };

  config = {
    home.stateVersion = "26.05";
    home.enableNixpkgsReleaseCheck = false;

    # overlay 说明：useGlobalPkgs = true（见 flake.nix 的 mkHomeManager）后，
    # HM 复用系统级 nixpkgs 实例——NUR 与自定义包（主题 / mcpp 等）由
    # modules/nixos/core 与 modules/darwin/base 在系统级统一注入，本模块不维护
    # nixpkgs.overlays / allowUnfree：在这里抹掉 HM 与 nixpkgs 的 API 差异会
    # 把两边的版本绑定死，别再引入。
  };

  # 公共层：所有主机（server / wsl / macbook 也装）无条件导入；
  # dev 与 gui 由各角色 profile 按需导入
  imports = [
    ./common
  ];
}
