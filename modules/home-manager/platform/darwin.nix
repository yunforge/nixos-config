# 平台适配：macOS（nix-darwin 上的 Home Manager）
#
# 只放「在 macOS 上才成立、且与具体主机无关」的用户级适配。
# macOS 的系统设置与 GUI 软件安装由 modules/darwin 管理，不在这里重复。
{ ... }:
{
  # 占位层：目前 macOS 用户环境与公共配置完全一致，此模块仅保留分层完整性
  # 与未来扩展入口（如需要为 macOS 单独调整 XDG、LaunchAgent 等）。
  config = { };
}
