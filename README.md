# os/ubuntu

从 `~/source/mytool/os`（原 `wsw_os_config`）迁移过来。**新版只做两件事，且都是声明式的**：

| 事项 | 声明 | 机制 |
|---|---|---|
| 换 apt 源 | `<system-file kind="apt-mirror" mirror="ustc" dest="auto"/>` | 引擎读 `/etc/os-release` 识别发行版与 codename，生成 deb822 内容 |
| 装基础软件包 | `<provision src="provision/packages.yaml" runner="ansible"/>` | Ansible 的 `package` 模块，幂等 |

## 用法

```sh
# 换源 + 装包（需要 root）
wtool provision os/ubuntu --with-system

# 只看计划，不动系统
wtool provision os/ubuntu --with-system --dry-run

# 撤销换源（装包不管，apt 包删掉即可）
wtool uninstall os/ubuntu
```

## 与 mytool 版本的差异

| 原 mytool | 现在 | 原因 |
|---|---|---|
| 10 个静态 `ustc/*.sources.list` + `tuna/*.sources.list` | **删掉**，改为引擎按发行版自动生成 | 不用再为每个版本维护一份文件；22/24/26 都能识别 |
| 旧的一行式 `deb https://...` 格式 | **deb822**（`Types:/URIs:/Suites:/Components:/Signed-By:`） | Ubuntu 24.04 起 `/etc/apt/sources.list` 已让位给 `sources.list.d/ubuntu.sources` |
| `cp /etc/apt/sources.list` + 手工备份 | 备份到 state 目录，`uninstall` 自动还原 | 可逆、可审计 |
| `sudo apt-get install -y ${base[@]} ...` | Ansible playbook | 幂等、可重跑、跨发行版 |
| 硬编码 `/etc/apt/sources.list` | `dest="auto"` → 由发行版决定目标文件 | 24.04 要写 `sources.list.d/ubuntu.sources` |

## 自动识别是怎么做的

```
/etc/os-release →  ID=ubuntu  VERSION_ID=24.04  VERSION_CODENAME=noble  ID_LIKE=debian
                   ↓
kind=apt-mirror + mirror=ustc
                   ↓
Types: deb
URIs: https://mirrors.ustc.edu.cn/ubuntu/
Suites: noble noble-updates noble-backports noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
                   ↓
写到 /etc/apt/sources.list.d/ubuntu.sources（写前备份）
```

支持的镜像：`ustc` / `tuna` / `aliyun`。
支持的发行版：`ubuntu` / `debian`（deb822），`rocky` / `centos` / `rhel` / `almalinux` / `fedora`（yum `.repo`）。

## 依赖

- `ansible-core`（1.4MB / 3 个包）：`sudo apt-get install -y --no-install-recommends ansible-core`
- 引擎在跑任务前会检查 `ansible-playbook` 是否存在，缺了会直接报错并给出这条命令。

## 文件

| 文件 | 作用 |
|---|---|
| `wtool.xml` | 清单：1 个 system-file + 1 个 provision |
| `provision/packages.yaml` | Ansible playbook（包列表来自原 `wsw_install.sh`） |
| `readme.md` | 原文件，保留 |
| `install.sh` / `uninstall.sh` | bootstrap 存根 |

> 原 `wsw_install.sh` 与 10 个静态源文件已删除（git 历史里仍有）。
> 需要自定义源内容时，把 `<system-file>` 换成 `src="你自己的文件"` 即可。
