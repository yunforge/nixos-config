# Shell 配置
# 门控：目录导入即生效（mengw.cli.enable 控制整个 CLI 层），无中间层开关；
# 单独关闭某个叶子（如 fish）用该叶子自己的 enable 选项。
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cliCfg = config.mengw.cli;
in
{
  imports = [
    ./fish.nix
  ];

  config = lib.mkIf cliCfg.enable {
    # ── 一、shell 环境与目录导航（速查表 / direnv / ls / cd） ───────────────────────

    # 快捷键速查表
    xdg.configFile."cheatsheets/" = {
      source = ./../cheatsheets;
      recursive = true;
      force = true;
    };

    # direnv：只装 pkgs.direnv 不会生效——它需要 shell hook 才会在进出目录时
    # 装载/卸载 .envrc，而 hook 由本模块注入（enableFishIntegration 本可省，
    # 它默认跟随 programs.fish.enable，这里写明是为了让依赖关系一眼可见）。
    # nix-direnv 默认为真，写明是因为仓库本身走 flake：它把 use flake 的 devShell
    # 缓存到 .direnv/，避免每次重算。
    programs.direnv = {
      enable = true;
      enableFishIntegration = true;
      # 加速 use flake（生成 ~/.config/direnv/lib/hm-nix-direnv.sh）
      nix-direnv.enable = true;
      # Git 全局忽略 .direnv/：否则 use flake 产生的工作树会让 git 树变脏
      enableGitIntegration = true;
      # 不在提示符里回显环境变量差异
      config.global.hide_env_diff = true;
    };

    # ls 的现代替代；fish 的 ls / ll / la / lla / lt 别名由该模块生成
    programs.eza = {
      # 启用 eza
      enable = true;
      # 文件图标
      icons = "auto";
      # 彩色输出
      colors = "auto";
      # 启用 Fish 集成
      enableFishIntegration = true;
      # Git 状态
      git = true;
      # 额外的 eza CLI 参数
      extraOptions = [
        # 目录排在文件前
        "--group-directories-first"
        # long view 显示列标题
        "--header"
      ];
    };

    # cd 的现代替代；接管内置 cd（--cmd cd）并注入补全，包也由模块安装，
    # 故 home.packages 里不再重复列。
    programs.zoxide = {
      enable = true;
      # 本可省（默认跟随 programs.fish.enable），写明是为了让依赖关系一眼可见
      enableFishIntegration = true;
      options = [
        # 接管 cd：得到 `cd <关键字>` 跳转与 `cdi` 交互选择
        # （不加则为 z / zi 两个新名字，见 docs/fish.md）
        "--cmd cd"
      ];
    };

    # zoxide 内置默认只把 $HOME 自身排除在库外，这里再排掉系统目录，免得补全
    # 候选里混进 /usr/bin、/nix/store、/var/log 这种一辈子不会 cd 进去的路径
    # （实测本机库中已积累 /etc、/usr、/var、/run、/dev 等条目）。
    # 注意**没有排 /etc**：/etc/nixos 是要进去看的真实目录，排掉它就完全进不来；
    # 代价是 /etc/fonts 之类也会进候选。
    # ⚠️ 两个实测坑：① 设置 _ZO_EXCLUDE_DIRS 是**替换**内置的 $HOME 默认值、
    # 不是追加，所以 home 必须显式写回；② zoxide 不展开 $HOME / ~，只认绝对
    # 路径。通配符 * 会跨越 `/`，故 `/usr*` 同时覆盖 /usr 自身与其全部子目录。
    home.sessionVariables._ZO_EXCLUDE_DIRS = lib.concatStringsSep ":" [
      # 写回内置默认：只排 $HOME 自身，故 ~/Projects 这类子目录仍会入库
      config.home.homeDirectory
      "/nix*"
      "/usr*"
      "/var*"
      "/run*"
      "/dev*"
      "/proc*"
      "/sys*"
      "/.snapshots*"
    ];

    # ── 二、常用 CLI 工具（gh / bat / ripgrep / fd / jq / tldr） ──────────────

    # GitHub CLI；config.yml 由 HM 生成（gh config set 的改动会被下次激活覆盖，改配置回仓库），
    # hosts.yml 与认证状态留给 gh 自己；gitCredentialHelper.enable 默认为 true，helper 自动写入
    programs.gh = {
      # 启用 gh
      enable = true;
      settings = {
        # 执行 git 操作时使用的协议
        git_protocol = "ssh";
        # 启用交互式提示
        prompt = "enabled";
        # 长输出使用 less
        pager = "less";
        # gh 在创建议题、拉取请求时默认编辑器
        editor = "nvim";
      };
    };

    # 现代 CLI 工具：bat / ripgrep / fd / jq 一律走 programs.<name>，
    # 不再在 home.packages 里裸装 —— 模块负责装包，并把「配置放哪」也定下来
    # （别名、hook、环境变量由模块接线，见各自的注释）。
    # 配色统一跟终端调色板（Noctalia 渲染的那 16 色，见 docs/themes.md）：bat 用
    # Catppuccin Frappe/Latte（终端 16 色的同源上游），jq 直接用 ANSI 槽号。

    # cat 的现代替代。
    #
    # ⚠️ 接管 ~/.config/bat/config 后，Noctalia 的 bat 社区模板就失效了：那个模板往这个
    # 文件里写 --theme=noctalia，并按当前调色板渲染 themes/noctalia.tmTheme。它的
    # apply.sh 开头是 `touch "$config_file"`，落在 HM 的只读软链上会以非 0 退出
    # （实测 exit 1：touch: Read-only file system）。Noctalia 只把它记进日志、不会损坏
    # 文件，bat 从此按下面这份配置走。旧模板若仍开着，建议在 Noctalia 模板列表里关掉
    # —— 那张表存在运行时 state 里，改 Nix 不生效（见 docs/themes.md）。
    #
    # theme = "auto"：bat 查终端背景色（OSC 10/11），暗色用 theme-dark、亮色用 theme-light。
    # 这是 bat 的默认取值，这里钉的是两态都用 Catppuccin：暗 = Frappe、亮 = Latte，
    # 与 Noctalia 的 terminal 16 色同源，故 `cat` / `bat` 与终端配色一致。
    # 注意：stdout 不是终端时（管道、fzf 预览）bat 不做探测，会回落自带默认主题；
    # 要强制某个主题就设 BAT_THEME。
    programs.bat = {
      enable = true;
      config = {
        tabs = "2";
        pager = "less -FR";
        style = "numbers";
        color = "always";
        theme = "auto";
        theme-dark = "Catppuccin Frappe";
        theme-light = "Catppuccin Latte";
      };
    };

    # grep 的现代替代；模块把 RIPGREP_CONFIG_PATH 指向生成的 ~/.config/ripgrep/ripgreprc
    programs.ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        # 连隐藏文件一起搜（.github/、.env 之类），但别钻进 .git
        "--hidden"
        "--glob=!.git/"
        "--glob=!.direnv/"
        "--glob=!result/"
        "--max-columns=200"
        "--max-columns-preview"
      ];
    };

    # find 的现代替代
    programs.fd = {
      enable = true;
      # 模块据此生成别名 fd → `fd --hidden`，点文件默认可见
      hidden = true;
      # 全局忽略文件（~/.config/fd/ignore）：省得每个项目再写 .fdignore。
      # 只是「默认」，fd -u / --no-ignore 可绕过
      ignores = [
        ".git/"
        ".direnv/"
        "result"
        "node_modules/"
        "target/"
        "__pycache__/"
        ".venv/"
      ];
    };

    # json 处理器；颜色由模块写进 sessionVariables 的 JQ_COLORS 生效（对所有 shell 一致）
    programs.jq = {
      enable = true;
      # 槽位顺序固定：null:false:true:numbers:strings:arrays:objects:objectKeys。
      # 用 ANSI 16 色槽号而不是写死真彩色：具体色值由终端调色板提供，切亮/暗
      # （Noctalia 重渲终端 16 色）时 jq 输出跟着变 —— 与 tmux「颜色全用 ANSI 名称」
      # 同一口径。jq 默认只给 null / 字符串 / 键上色，这里把布尔与数字也分开：
      #   null 暗色、false 红、true 绿、数字青、字符串黄、数组品红、对象与括号白、键蓝
      colors = {
        null = "90";
        false = "31";
        true = "32";
        numbers = "36";
        strings = "33";
        arrays = "35";
        objects = "37";
        objectKeys = "34";
      };
    };

    # man 的现代替代。它有官方 HM 模块，故走 programs.<name>。
    # ⚠️ 模块装的是 Rust 实现的 tealdeer（命令名仍叫 tldr），与原先裸装的
    # pkgs.tldr（Python 客户端）不是同一个程序：缓存从 ~/.cache/tldr 换到
    # ~/.cache/tealdeer，配置落在 ~/.config/tealdeer/config.toml。
    programs.tealdeer = {
      enable = true;
      # 默认即 true，写出来是因为它有可感知的副作用：装一个 systemd user
      # timer（weekly 跑 tldr --update 拉页），darwin 上对应 launchd agent
      enableAutoUpdates = true;
      # 没有缓存时首次调用自己拉一份，否则要等 timer 到点才可用
      settings.updates.auto_update = true;
    };

    # ── 三、裸装包与 Git ────────────────────────────────────────────────────

    # dust / yq / sysstat / git-repo 上游没有 programs.<name> 模块（查过
    # pinned HM 的全部 programs.* 选项），只能裸装：前两个的配置靠各自 env /
    # 配置文件，sysstat 是系统级采集（NixOS 侧只有 services.sysstat，且它是
    # root 定时采集、不装 CLI），git-repo 无配置面。
    home.packages = with pkgs; [
      dust # du 的现代替代
      yq # yaml/xml/toml 处理器
      sysstat # Linux的性能监控工具集（如sar、iostat和pidstat）
      git-repo # android 的仓库管理工具
    ];

    # Git
    programs.git = {
      enable = true;
      settings = {
        user.name = "meng.wang";
        user.email = "meng.w1016@outlook.com";
        init.defaultBranch = "main";
        core.editor = "nvim";
        color.ui = "auto";
        push.autoSetupRemote = true;
      };
    };
  };
}
