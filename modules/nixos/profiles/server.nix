# 角色配置（系统层）：NixOS 服务器
#
# 与工作站的区别：
#   - 不启用桌面（mySystem.desktop.enable 保持关闭，GDM / Niri / 输入法 /
#     音视频栈全部不加载）
#   - 硬件只保留服务器相关项（默认全关，由具体主机按需开启，
#     如某台服务器需要 WiFi 或音频再单独打开）
#   - SSH 认证收紧、防火墙策略明确、不做自动重启
#
# 继承自 core 的系统基础（引导 / Nix / 用户 / locale / SSH / GC /
# 自动升级）是所有 NixOS 主机共享的，此处不重复。
{ lib, ... }:
{
  # 明确不启用工作站能力；主机若真需要某项（如跑容器的服务器开虚拟化）
  # 可在 hosts/<host>/default.nix 里显式打开
  mySystem.hardware.enable = lib.mkDefault false;
  mySystem.desktop.enable = lib.mkDefault false;

  # ── 服务器安全策略 ──────────────────────────────────────────────
  # core 的 SSH 默认允许密码认证（为局域网登录保留）。服务器面向不可信网络，
  # 必须改用密钥认证：关掉密码登录，只留端口 22（firewall 由 core 放行）。
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce false;
    KbdInteractiveAuthentication = lib.mkForce false;
    PermitRootLogin = lib.mkForce "prohibit-password";
  };

  # 服务器不连桌面代理（mihomo 在本机监听 127.0.0.1 的前提是桌面会话；
  # 需要代理的服务器在 hosts/<host>/ 里显式开 mySystem.proxy.enable）
  mySystem.proxy.enable = lib.mkDefault false;
}
