# NVIDIA 驱动公共基础配置
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mySystem.hardware;
in
{
  # 依赖 mySystem.hardware.enable：NVIDIA 配置体由该开关共同门控，且音频/图形等
  # 配套支持也由它统一启用。单独开启本开关会静默失效，见下方 assertions。
  options.mySystem.hardware.nvidia.enable =
    lib.mkEnableOption "NVIDIA 驱动（须同时开启 mySystem.hardware.enable）";

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.nvidia.enable && !cfg.enable);
          message = ''
            mySystem.hardware.nvidia.enable 已开启，但 mySystem.hardware.enable 未开启。
            NVIDIA 驱动配置仅在二者同时开启时生效，否则 videoDrivers 不会被设为 "nvidia"，
            主机 nvidia.nix 中的 package/prime 等设置也会静默失效（构建通过但开机无驱动）。
          '';
        }
      ];
    }

    (lib.mkIf (cfg.enable && cfg.nvidia.enable) {
      services.xserver.videoDrivers = [ "nvidia" ];

      # nvidia-drm.modeset=1 不手写：下方 modesetting.enable = true 会让
      # nixpkgs 的 NVIDIA 模块注入同一参数
      boot.kernelParams = [
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        "nvidia.NVreg_TemporaryFilePath=/var/tmp"
        "nvidia.NVreg_UseKernelSuspendNotifiers=1"
      ];
      boot.blacklistedKernelModules = [ "nouveau" ];

      # PRIME offload 主机（iGPU 显示、dGPU 按需唤醒）不能全局注入下列几个变量：
      # 它们强制 Mesa / VA-API 的所有客户端走 dGPU 后端，轻则 GNOME 硬件加速异常，
      # 重则阻止 dGPU 进入 D3cold 直接吃续航。offload 模式应按程序经 nvidia-offload
      # wrapper 注入（wrapper 已自带 __GLX_VENDOR_LIBRARY_NAME=nvidia）。
      # 余下两个与渲染设备无关：__GL_VRR_ALLOWED / NVD_BACKEND 仅在用到 NVIDIA 时被读取，
      # iGPU 上均为惰性。
      environment.variables =
        (lib.optionalAttrs (!config.hardware.nvidia.prime.offload.enable) {
          LIBVA_DRIVER_NAME = "nvidia";
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";

          # EGL（GTK4 / Qt5 / WebKit 走的路）要拿到 NVIDIA，须让 glvnd 找到
          # NVIDIA 的外部平台：它的 Wayland/X11/GBM 平台不在 glvnd 内置支持里，
          # 而由 egl_external_platform.d/*.json 声明。glvnd 只编译进了
          # egl_vendor.d 的默认路径，外部平台目录没有默认值，不指路就永远不加载。
          # __GLX_VENDOR_LIBRARY_NAME 只管 GLX（X11 的 OpenGL），对 EGL 无效，
          # 所以 EGL 一直落到 Mesa 的 swrast（软件渲染）。
          __EGL_EXTERNAL_PLATFORM_CONFIG_DIRS = "/run/opengl-driver/share/egl/egl_external_platform.d";
          # glvnd 的 EGL_DEFAULT_DISPLAY 会先落到 Mesa，须显式指定平台，
          # EGL 才用上 NVIDIA 的外部平台。
          EGL_PLATFORM = "wayland";
        })
        // {
          __GL_VRR_ALLOWED = "1";
          NVD_BACKEND = "direct";
        };

      nixpkgs.config.nvidia.acceptLicense = true;

      hardware = {
        nvidia = {
          open = false;
          nvidiaSettings = true;
          powerManagement.enable = true;
          modesetting.enable = true;
        };
        # graphics.enable 不在此声明：hardware 域聚合（../default.nix）已随
        # mySystem.hardware.enable 给出 mkDefault true（上方 assertion 保证其开启）
        graphics = {
          enable32Bit = true;
          extraPackages = with pkgs; [
            nvidia-vaapi-driver
            egl-wayland
            libva
          ];
        };
      };

      # niri NVIDIA VRAM 泄漏修复
      environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json" =
        {
          text = ''
            {
                "rules": [
                    {
                        "pattern": {
                            "feature": "procname",
                            "matches": "niri"
                        },
                        "profile": "Limit Free Buffer Pool On Wayland Compositors"
                    }
                ],
                "profiles": [
                    {
                        "name": "Limit Free Buffer Pool On Wayland Compositors",
                        "settings": [
                            {
                                "key": "GLVidHeapReuseRatio",
                                "value": 0
                            }
                        ]
                    }
                ]
            }
          '';
        };

      environment.systemPackages = with pkgs; [
        vulkan-tools
        mesa-demos
        libva-utils
      ];
    })
  ];
}
