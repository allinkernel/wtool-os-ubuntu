# BACKLOG —— os/ubuntu

> 这个文件是这个项目"接下来做什么、做到哪了"的**唯一权威**。
> 引擎/跨项目的事在 `~/self/wtool/harness/BACKLOG.md`，别混。
>
> 状态：⬜ 待做 · 🔄 在做 · ✅ 做完（写清怎么做的、验证到什么程度）· ⏸ 待决定（要人来拍）

---

## ⏸ 待拍板

### 1. `zstd` 还留在基础包列表里吗

**现状**（2026-10-04 P2 核对时发现，**只改了文档，没动包列表**）：
`provision/packages.yaml` 的 1/7 task 里有 `zstd`，文件里的注释写着
"wtool publish 优先用它打包（多线程、压缩率比 gzip 好很多）；没有它也不会出错，
但资产名会变成 `.tar.gz`"。**这两句现在都不成立**：

- 引擎的打包是 `wtool pack-release`（发布是 `publish-release`），不再叫 `wtool publish`；
- 产物固定是 `source.zip` / `release.zip`（`bootstrap/lib/wtool_fs.sh` 的 `wt_zip_create`
  → `python3 wtool_zip.py create`），**不再按压缩器挑扩展名**
  （2026-10-04 核对时源码包叫 `源码.zip`；2026-10-09 改成 ASCII 名 —— ADR-0040）；
- 判据：`grep -rn 'zstd' bootstrap/lib/wtool_fs.sh` → 只有 `*.tar.zst) tar --zstd -xf ...`
  一条，那是 `unpack-release` 解**旧版包**的兼容分支，跟打包无关。

**要人拍**：① 删掉 `zstd`（同时改 `provision/packages.yaml` 里那条注释）；
② 留着（**当前就是**，装了不碍事，只是没用）；③ 留着但把注释改成"历史遗留"。

⚠️ 注意：`zstd` 同时出现在 README「四、基础软件包」那张表里，删包要两处一起改。
另外 `bootstrap/` 正在被别的会话改 —— 上面关于打包的结论是 2026-10-04 这一版的引擎行为，
拍板前可以重跑一次判据。

---

## ✅ 做完的

- **2026-10-04 P2 文档核对**（本次提交）：
  - 订正 README 里 `zstd`／`wtool publish` 那段过期结论（见上，原结论来自 `f56afcd`）；
  - 补上 `mirror.txt` 的**确切格式**（`<代号>\t<主机名|->\t<来源>\t<时间>`，
    第二列主机名才是引擎反查用的）—— 格式没写清会让人误判"文档错了"；
  - 安装一节补容器规矩（这一层改 `/etc`、装包，真机必须用户明确同意）；
  - `## 文件` 表补 `AGENTS.md` / `BACKLOG.md`，正文里 `git ls-files` 的清单补齐。
  - 验证：引擎侧 `sh bootstrap/tests/provision_test.sh` → `PASS: 40  FAIL: 0`；
    `plan-provision` 四种情形（无 mirror.txt / ustc / official / WTOOL_HEAVY=1）
    的输出与 README 那张表逐条对上；真 `$HOME` 跑前跑后 `stat` 逐字不变。
