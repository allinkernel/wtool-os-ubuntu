# os/ubuntu

Ubuntu 的**系统层**声明：换 apt 源 + 装基础软件包（可选再加一套重型工具链）。
全部是声明式的 —— 项目里**没有一行"装包脚本"**，装什么、怎么装由引擎按
`wtool.xml` 里的 `<sudo-install>` 执行。

> 要 **root**：这一层由 `wtool sudo-install` 跑（**要 sudo 的都叫 `sudo-*`**）。
> 本项目**没有** `install.sh` / `uninstall.sh`（存根早就删了，见提交 `8adf8dc`）。

## 安装

一句话：`wtool sudo-install os/ubuntu`。

下载与安装的**唯一入口**在 GitHub 上：

> **[wtool-base/README.md](https://github.com/allinkernel/wtool/blob/main/README.md)**

（URL 由清单 `.repo/manifests/default.xml` 里的 remote `ssh://git@github.com/`
+ 项目名 `allinkernel/wtool-os-ubuntu.git` + 默认 revision `main` 拼出，不是猜的。）

撤销：`wtool sudo-uninstall os/ubuntu`（见「六、可逆性」）。

## 功能说明

### 一、声明了什么

`wtool.xml` 里只有**三条** `<sudo-install>`，`priority=5`（最早执行，
保证后面编译型项目有编译器和依赖）：

| # | 声明 | 装什么 | 什么时候装 |
|---|---|---|---|
| 1 | `kind="apt-mirror" mirror="auto" dest="auto" mode="replace" backup="true"` | apt 源（写到 `/etc/apt/sources.list.d/ubuntu.sources`） | `when="os:ubuntu"` |
| 2 | `src="provision/packages.yaml" marker="apt-base"` | 24 个基础软件包 | `when="os:ubuntu"` |
| 3 | `src="provision/toolchain.yaml" marker="apt-toolchain"` | 18 个重型工具链包（1GB+） | `when="os:ubuntu,env:WTOOL_HEAVY"` —— **设了 `WTOOL_HEAVY=1` 才装** |

> `<system-file>` 和 `<provision>` 是**旧标签**，已并进 `<sudo-install>`
> （引擎仍然认，但每次解析都会警告并指路）。这个项目的两个标签都已经迁过来了
> （提交 `dbe3d98`）。

### 二、怎么跑

```sh
wtool sudo-install   os/ubuntu     # 换源 + 装基础包（要 sudo）
wtool sudo-install   os/ubuntu --dry-run   # 只看计划，不动系统
wtool sudo-uninstall os/ubuntu     # 还原 /etc + 卸掉装进来的 apt 包
wtool sudo-bootstrap               # = 所有声明了 <sudo-install> 的项目逐个来一遍
WTOOL_HEAVY=1 wtool sudo-install os/ubuntu   # 连重型工具链一起装
```

* `--with-system` / `--no-system` **已经删掉**：`sudo-install` 本来就是系统层，
  敲旧参数会**直接报错并告诉你去掉它**（不会静默忽略）。
* `--force` 可以重跑已经打过 marker 的任务（见「六、可逆性」）。

### 三、apt 源：`mirror="auto"` 是什么意思

**auto = 听 `install.sh` 的**（2026-10-04 用户要求：换源只有一处逻辑）。

`install.sh` 第 0 步会测速、让你挑一个镜像，并把选择记进
`<state>/mirror.txt`。系统层这条声明就照它来 —— 用真清单跑一次引擎的计划
（`plan-provision`，只算不写）能直接看出三种情形：

| `mirror.txt` | 引擎的动作 | 说明 |
|---|---|---|
| **没有记录** | `replace /etc/apt/sources.list.d/ubuntu.sources`（backup=yes） | 用老默认 **ustc** |
| 记了 `ustc` 等已知镜像 | `dedup` —— **跳过换源**，顺手清掉会重复的那份 | install.sh 已经换过了 |
| 记了 `official`（你选了官方源） | `dedup` —— 同上 | 不该再动源 |

实测（`plan-provision` 的输出，`sysfiles.tsv` 第一列就是动作）：

```
# 没有 mirror.txt：
replace	/etc/apt/sources.list.d/ubuntu.sources	<临时文件>	<sha256>	yes	apt 源（跟随 install.sh 里挑的那个镜像）
# 有 mirror.txt（ustc）：
dedup	/etc/apt/sources.list.d/ubuntu.sources			no	apt 源（跟随 install.sh 里挑的那个镜像）
```

**为什么非要这样**：机器上出现两份源文件时 apt 会警告
`Target Packages ... is configured multiple times`，而且 ansible 的装包任务会因此失败
（实测，见 `harness/docs/hazards.md` H20）。想固定用某一个镜像，就把 `auto`
换成镜像代号。

| 项 | 值 |
|---|---|
| 认的镜像代号（apt / debian） | `ustc`、`tuna`、`aliyun`、`huawei`、`netease`、`tencent`（引擎里的表，6 个） |
| 选的镜像不对 / 想固定 | 把 `mirror="auto"` 改成上面任一代号 |
| 目标文件（`dest="auto"`） | Ubuntu → `/etc/apt/sources.list.d/ubuntu.sources`；Debian → `debian.sources` |
| 格式 | **deb822**（`Types:` / `URIs:` / `Suites:` / `Components:` / `Signed-By:`） |
| 写入方式 | `mode="replace"` + `backup="true"` → **写前备份，卸载时自动还原** |
| 发行版识别 | 引擎读 `/etc/os-release`（`ID` / `VERSION_ID` / `VERSION_CODENAME`），不写死 |

支持的发行版：`ubuntu` / `debian`（deb822），以及 `rocky` / `centos` / `rhel` /
`almalinux` / `fedora`（yum `.repo`）—— 但本项目的 `when="os:ubuntu"` 只在 Ubuntu 上跑。

### 四、基础软件包（`provision/packages.yaml`）

Ansible playbook，`become: true`、`DEBIAN_FRONTEND=noninteractive`，
分成 **7 个 task**（一个大 task 会静默好几分钟，看不见进度），共 **24 个包**：

| task | 包 |
|---|---|
| 1/7 基础工具 | `tree` `apt-file` `git` `ranger` `dos2unix` `bat` `zstd` |
| 2/7 shell 与终端 | `zsh` `tmux` |
| 3/7 编辑器 | `vim` `neovim` |
| 4/7 远程与网络工具 | `openssh-server` `curl` `wget` `net-tools` |
| 5/7 搜索工具 | `ripgrep` `fd-find` `silversearcher-ag` |
| 6/7 构建基础 | `make` `cmake` `binutils` |
| 7/7 杂项与可视化 | `graphviz` `sl` `neofetch` |

用 `ansible.builtin.package` 模块（**幂等、可重跑**）。`zstd` 是给
`wtool publish` 打包用的（没有它也能打包，只是资产变成 `.tar.gz`）。

### 五、重型工具链（`provision/toolchain.yaml`）

**只在设了 `WTOOL_HEAVY=1` 时**才跑（`when="os:ubuntu,env:WTOOL_HEAVY"`；
逗号分隔 = AND）。3 个 task，共 **18 个包**，1GB 以上：

| task | 包 |
|---|---|
| 1/3 编译器与调试器 | `clang` `llvm` `clangd` `gcc` `gdb` `autoconf` `automake` `build-essential` `flex` `bison` `nasm` `texinfo` |
| 2/3 开发库（含 32 位） | `libelf-dev` `libssl-dev` `libcurl4-openssl-dev` `gcc-multilib` `libc6-dev-i386` |
| 3/3 emacs | `emacs` |

实测：不设 `WTOOL_HEAVY` 时引擎会警告
`when=os:ubuntu,env:WTOOL_HEAVY 不匹配，跳过任务`，计划里只有 1 个 task；
设了就是 2 个。

> `when=` 支持 `os:ubuntu`、`!os:debian`、`arch:x86_64`、`env:NAME`
> （`env:` 的判据：变量有值且不是 `0`/`false`/`no`）。**未知条件按不匹配处理** ——
> 不会误执行。

### 六、可逆性：什么能回退，什么不能

| 东西 | 可逆吗 | 依据 |
|---|---|---|
| `/etc` 下的源文件 | **可逆** | `system.tsv` 记着落点与备份；`wtool sudo-uninstall` 按它**还原** |
| apt 包 | **可逆** | `apt.tsv` 是"这次装进来的"差集快照；`sudo-uninstall` 会 `apt-get remove` 它们 |
| 任务跑过没 | 靠 **marker** | `provisioned/<marker>`（这里是 `apt-base` / `apt-toolchain`）；已存在就跳过，`--force` 可以重跑 |

`wtool uninstall`（用户层）**不会**删 `system.tsv` —— 两层各有各的账；
它删了的话 `sudo-uninstall` 就再没依据还原了。

### 七、依赖

| 依赖 | 说明 |
|---|---|
| **root / sudo** | 这一层全是系统级操作 |
| **ansible** | playbook 的 runner。引擎在跑之前会检查 `ansible-playbook`；**缺了会自己 `apt-get install` 试一遍**（包名逐版本试：22.04+ 是 `ansible-core`，20.04 只有 `ansible`），自动装也失败才报错并给出两条命令 |
| **Ubuntu** | `when="os:ubuntu"` 限定 |
| 网络 | 要从源下包 |

## 测试

这个项目**自己没有测试脚本** —— 它是一份声明，测的是**引擎的 `sudo-install` 层**：

```sh
cd bootstrap/tests && sh provision_test.sh     # 40 条（sudo-install 层：系统文件 / source / task）
```

其中**场景 9** 就是 `mirror="auto"` 跟随 `install.sh` 那条逻辑。

想验**这个项目自己的清单**（只算不写、不动系统）：

```sh
cd ~/self/wtool
python3 bootstrap/lib/wtool_plan.py plan-provision "$PWD/os/ubuntu" \
  --home "$HOME" --state <临时状态目录> --scratch <临时目录> \
  --os-id ubuntu --os-codename noble --arch x86_64
# 打印 "actions: N sysfile, N source, N task"，并把逐条计划写进 <scratch>/sysfiles.tsv、tasks.tsv
```

> ⚠️ **没有在真系统上跑过 `sudo-install`**（那要 sudo + root，本次改造只改文档）。
> 上面那些结论来自读引擎代码 + `plan-provision` 的实跑输出，**不是端到端验证**。

## 与 mytool 版本的差异

| 原 mytool | 现在 | 原因 |
|---|---|---|
| 10 个静态 `ustc/*.sources.list` + `tuna/*.sources.list` | **删掉**，改为引擎按发行版自动生成 | 不用再为每个版本维护一份文件；22/24/26 都能识别 |
| 旧的一行式 `deb https://...` 格式 | **deb822**（`Types:/URIs:/Suites:/Components:/Signed-By:`） | Ubuntu 24.04 起 `/etc/apt/sources.list` 已让位给 `sources.list.d/ubuntu.sources` |
| `cp /etc/apt/sources.list` + 手工备份 | 备份进 state 目录，`sudo-uninstall` 自动还原 | 可逆、可审计 |
| `sudo apt-get install -y ${base[@]} ...` | Ansible playbook | 幂等、可重跑、跨发行版 |
| 硬编码 `/etc/apt/sources.list` | `dest="auto"` → 由发行版决定目标文件 | 24.04 要写 `sources.list.d/ubuntu.sources` |
| `<system-file>` / `<provision>` 两个标签 | `<sudo-install>` 一个标签 | 一个标签覆盖"系统文件 / 跑脚本 / 跑 playbook"三类；旧标签仍认但警告 |
| `wtool provision --with-system` | `wtool sudo-install` | 要 sudo 的都叫 `sudo-*`；`--with-system` 已删（敲了会报错指路） |

> 原 `wsw_install.sh` 与 10 个静态源文件已删除（git 历史里仍有）。
> 原 README 里提到的 `readme.md`、`install.sh` / `uninstall.sh` 存根
> **现在都不在仓库里**（`git ls-files` 只有 `README.md`、`provision/*.yaml`、`wtool.xml`）。

## 文件

| 文件 | 作用 |
|---|---|
| `wtool.xml` | 清单：3 条 `<sudo-install>`（换源 / 基础包 / 重型工具链） |
| `provision/packages.yaml` | 基础软件包的 Ansible playbook（7 个 task，24 个包） |
| `provision/toolchain.yaml` | 重型工具链（3 个 task，18 个包，要 `WTOOL_HEAVY=1`） |
