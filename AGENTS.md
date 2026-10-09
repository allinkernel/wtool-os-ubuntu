# AGENTS.md —— os/ubuntu

> 先读用户级 `~/.dsh/AGENTS.md`（工作区通用规则）和仓库根 `AGENTS.md`（多仓库工作区规则），
> 本文件只讲**这个项目**的事。

## 这个项目是什么

Ubuntu 的**系统层声明**：换 apt 源 + 装基础软件包（+ 可选的重型工具链）。
**项目里没有任何安装脚本** —— 只有 `wtool.xml` 里三条 `<sudo-install>` 和两个
Ansible playbook。装、卸都由引擎执行：

| 文件 | 是干什么的 |
|---|---|
| `wtool.xml` | 三条 `<sudo-install>`：`kind="apt-mirror"` 换源 / `packages.yaml` 基础包 / `toolchain.yaml` 重型工具链 |
| `provision/packages.yaml` | 基础软件包（7 个 task、24 个包），`ansible.builtin.package`，幂等 |
| `provision/toolchain.yaml` | 重型工具链（3 个 task、18 个包），`when="os:ubuntu,env:WTOOL_HEAVY"` |

**这里没有 `scripts/install.sh`，也不该有** —— 加脚本就等于把"声明式"改成"命令式"，
而且 `sudo-install` 的可逆性（备份 / 还原 / marker / apt 差集）都建立在声明上。
顺带说明：`install.sh` / `uninstall.sh` 存根早在 `8adf8dc` 就删了，
README 里**不要**再写出"怎么跑项目自己的 install.sh"。

## 铁律

1. **声明一有变化，必须在同一个提交里同步更新 `README.md`。**
   `README.md` 是**给用户的完整功能说明书**（不是开发笔记）。对应关系：
   加/改 `<sudo-install>` → 「一、声明了什么」+「二、怎么跑」；
   改 `provision/packages.yaml` → 「四、基础软件包」的包列表（**逐个列**，别只写"若干"）；
   改 `provision/toolchain.yaml` → 「五、重型工具链」；
   改 `when=` / marker → 「一」「六、可逆性」。
   **README 与代码不一致 = 缺陷**，不是"以后补"。

2. **README 里不写安装脚本的跑法。** 安装只有一句话
   （`wtool sudo-install os/ubuntu`，要 sudo）+ 一个链接到全局唯一下载/安装入口
   （GitHub 上 `wtool-base/README.md`）。

3. **只用 `<sudo-install>`，不要用旧标签。** `<system-file>` / `<provision>` 已被
   它并掉（引擎仍认但每次解析都警告）。改清单时别把它们写回来。

4. **`mirror="auto"` 不许改成写死的镜像。**
   换源**只有一处逻辑**：`install.sh` 第 0 步测速挑源并记进 `<state>/mirror.txt`，
   系统层照它来。系统层再按写死的 `mirror="ustc"` 写一份 `ubuntu.sources`，
   机器上就有两份源文件 → apt 警告 `configured multiple times` → **ansible 装包任务会失败**
   （实测，见 `harness/docs/hazards.md` H20）。

5. **`when="os:ubuntu"` 别删** —— 这个项目只对 Ubuntu 有意义。

6. **加包要考虑它们的"可逆性代价"**：apt 包由 `apt.tsv` 差集记录、
   `sudo-uninstall` 会 `apt-get remove`；**重型/体积大的包放 `toolchain.yaml`**
   （由 `WTOOL_HEAVY=1` 把关），不要塞进基础包。

7. **装 / 测只在容器里做。** 这一层**会改 `/etc`、会装包**（要 root）——
   本机（WSL）是临时的手工环境，wtool 调通之前不在本地落地；
   **真机上跑 `wtool sudo-install os/ubuntu` 必须由用户明确同意**，
   助手不得自行跑（用户级 `~/.dsh/AGENTS.md` 的硬规矩）。只看计划用 `--dry-run`。

8. **引用引擎行为的结论必须带判据。** README 里凡是"引擎会怎样"的话
   （打包格式、包名怎么试、警告原文……）都要附一条可复现命令 ——
   `bootstrap/` 一直在改，**已经踩过**：README 里"`zstd` 是给 `wtool publish` 打包用的、
   没有它资产会变成 `.tar.gz`"这段，在引擎改成 `pack-release` + `source.zip`/`release.zip`
   （当时还叫 `源码.zip`，2026-10-09 改 ASCII 名 —— ADR-0040）
   之后就变成了错话（2026-10-04 订正，见 `BACKLOG.md`「待拍板 1」）。

## README 章节结构（改了对应内容就改对应章节）

| 章节 | 内容 |
|---|---|
| （开头） | 一句话 + "全是声明式、没有装包脚本" + 要 sudo |
| `## 安装` | 一句话（`wtool sudo-install os/ubuntu`）+ wtool-base 链接 |
| `## 功能说明` → `一、声明了什么` | 三条 `<sudo-install>` 的表 + `priority=5` / 旧标签说明 |
| `## 功能说明` → `二、怎么跑` | `sudo-install` / `sudo-uninstall` / `sudo-bootstrap` / `--dry-run` / `WTOOL_HEAVY=1` |
| `## 功能说明` → `三、apt 源` | `mirror="auto"` 三种情形（实测输出）+ 镜像表 + deb822 + 目标文件 |
| `## 功能说明` → `四、基础软件包` | playbook 的每个 task 与**每个包名** |
| `## 功能说明` → `五、重型工具链` | 同上 + `WTOOL_HEAVY=1` 的判据 |
| `## 功能说明` → `六、可逆性` | `/etc` 还原 / apt 差集 / marker 各自依据什么 |
| `## 功能说明` → `七、依赖` | sudo、ansible（引擎会自己装）、Ubuntu、网络 |
| `## 测试` | 引擎的 `provision_test.sh` + 对自己清单跑 `plan-provision` |
| `## 与 mytool 版本的差异` / `## 文件` | —— |

## 测试

这个项目**没有自己的测试脚本**，测的是**引擎的 `sudo-install` 层**：

```sh
cd bootstrap/tests && sh provision_test.sh     # 40 条（含场景 9：mirror="auto" 跟随 install.sh）
                                               # 条数以脚本最后那行 PASS/FAIL 为准
```

这个测试**安全**（文件头写着：全程临时目录、不碰真 `$HOME`、不碰 `/etc`、不要 root）；
2026-10-04 实测 `PASS: 40  FAIL: 0`。

想验**本项目的清单**（只算不写、不动系统、不用 sudo）：

```sh
cd ~/self/wtool
T=$(mktemp -d); mkdir -p "$T/state" "$T/scratch"
python3 bootstrap/lib/wtool_plan.py plan-provision "$PWD/os/ubuntu" \
  --home "$HOME" --state "$T/state" --scratch "$T/scratch" \
  --os-id ubuntu --os-codename noble --arch x86_64
cat "$T/scratch/sysfiles.tsv" "$T/scratch/tasks.tsv"
rm -rf "$T"
```

预期：没设 `WTOOL_HEAVY` 时 `actions: 1 sysfile, 0 source, 1 task`（toolchain 被
`when=` 挡掉）；`WTOOL_HEAVY=1` 时是 `2 task`。`state` 目录里有 `mirror.txt`
时，第一条的动作应变成 `dedup` —— ⚠️ **`mirror.txt` 必须是四列 Tab 分隔**
（`<代号>\t<主机名|->\t<来源>\t<时间>`），**引擎用第二列主机名反查代号**；
只写一行 `ustc` 会被当成"没记录"、动作退回 `replace`（README「三」里有判据与例子）。

**绝不要为了"测一下"就在真机器上跑 `wtool sudo-install os/ubuntu`** ——
那会改 `/etc` 和装包。`--dry-run` 是安全的。

## 提交

改动只提交到 `ds_dev`（用户级规则见 `~/.dsh/AGENTS.md` §1）：`git add` 前先 `git diff`
看一遍、提交带 `-m`、**不 push、不动 `main`**。
