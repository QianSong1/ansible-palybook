1.通用说明指南
-------------------------------------------

这些剧本需要Ansible 1.2。

这些剧本手册旨在作为参考和入门指南

可靠的行动手册。这些剧本是在CentOS 6.x上测试的，因此我们建议您可以使用CentOS或RHEL来测试这些模块。

库存文件 **“hosts”** 定义了应该在其中配置堆栈的节点。

```yaml
[webservers]
localhost

[dbservers]
bensible
```

在这里，可以使用以下方法部署堆栈

命令：

```bash
# 验证主机清单
ansible -i hosts all --list-hosts

# 列出剧本任务列表
ansible-playbook -i hosts --list-tasks site.yaml

# 检查语法
ansible-playbook -i hosts --syntax-check site.yaml

# 模拟执行剧本
ansible-playbook -i hosts -C site.yaml

# 执行剧本
ansible-playbook -i hosts site.yaml
```

完成后，您可以通过 `ansible` 命令查看结果

您应该看到一个简单的测试结果。

```bash
# 验证配置
➜ ansible -i hosts all -m shell -a "ls -l /usr/local/bin && ls -l ~/.config/ && tail -n 2 ~/.zshrc"
192.168.44.209 | CHANGED | rc=0 >>
总用量 30628
-rwxr-xr-x. 1 root root 21446656 4月   8 2023 oh-my-posh
-rwxr-xr-x  1 root root  9915136 5月  16 01:10 starship
总用量 4
drwxr-xr-x. 2 root root   25 4月  12 2023 neofetch
drwxr-xr-x  4 root root  180 4月  29 10:35 nvim
drwx------. 2 root root    6 4月  13 2023 procps
-rw-r--r--  1 root root 2686 6月  28 16:50 starship.toml
# config starship PROMPT
eval "$(starship init zsh)"
```



## 2.系统journald优化流程

> 1. 安装 **`Python3`** 以及 **`ansible`** 核心
> 2. 编写剧本



## 3.安装 ansible 核心

编译安装 `Python3` 到 `/opt` 目录

与ansible依赖关系：[依赖矩阵](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html#managed-node-requirements)

将 Python 3 编译安装到 `/opt` 目录是企业级运维的推荐做法。这种方式遵循了 **FHS (Filesystem Hierarchy Standard)** 标准，将第三方大型软件独立存放，既不会污染系统路径，也极易于备份和删除。

以下是在 **AlmaLinux** 管理机上，将 Python 3.12 编译安装到 `/opt/python3.12` 的全流程：

------

### 3.1. 安装编译依赖

首先确保系统具备编译环境及必要的开发库：

```bash
[root@almalinux ~]# sudo dnf groupinstall "Development Tools" -y
[root@almalinux ~]# sudo dnf install -y openssl-devel \
libffi-devel \
bzip2-devel \
wget \
zlib-devel \
readline-devel \
sqlite-devel \
xz-devel \
tk-devel \
tar
```

------

### 3.2. 下载并准备源码

```bash
[root@almalinux ~]# cd /tmp
[root@almalinux /tmp]# sudo wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz
[root@almalinux /tmp]# sudo tar xzf Python-3.12.0.tgz
[root@almalinux /tmp]# cd Python-3.12.0
```

------

### 3.3. 配置安装路径（关键步骤）

通过 `--prefix` 参数指定安装到 `/opt/python3.12`。

- **`--prefix=/opt/python3.12`**：指定所有文件（bin, lib, share）都放在这个目录下。
- **`--enable-optimizations`**：极致优化性能。

```bash
[root@almalinux /tmp/Python-3.12.0]# sudo ./configure --prefix=/opt/python3.12 --enable-optimizations --with-ensurepip=install
```

------

### 3.4. 编译与安装

```bash
# 使用 -j 配合 CPU 核心数加速编译
[root@almalinux /tmp/Python-3.12.0]# sudo make -j $(nproc)

# 【慎重】此处可以直接使用 install，因为 prefix 已经隔离了路径
[root@almalinux /tmp/Python-3.12.0]# sudo make install

# 【推荐】既然是完全纯净的隔离安装，我们推荐 altinstall，因为它不会创建任何（不带版本号）的软链接，因此不会搞坏你的环境
[root@almalinux /tmp/Python-3.12.0]# sudo make altinstall
```

**为什么这么做？** 你的直觉是对的：既然指定了 `--prefix=/opt/python3.12`，理论上所有文件都应该被关进那个特定的“笼子”里。

但在实际执行 `make install` 时，情况可能比想象中复杂一点，主要涉及以下两个原因：

> 1. **编译脚本的默认行为**
>    虽然你指定了安装路径，但 Python 的 `Makefile` 在执行 `install` 目标时，除了拷贝二进制文件到 `/opt`，有时还会尝试在系统的全局路径（如 `/usr/local/bin`）中创建一些软链接（**Symbolic Links**），比如 `python3` 或 `pip3`。
>
>    如果你当前的系统已经有一个指向旧版本 Python 的 `/usr/local/bin/python3`，`make install` 可能会尝试覆盖它，导致原本依赖该路径的脚本出现兼容性问题。
>
> 2. **环境变量的“陷阱”**
>    即使它乖乖地待在 `/opt` 目录下，如果你为了使用方便，将 `/opt/python3.12/bin` 加入了系统的 PATH 变量的最前面，那么当你输入 `python3` 时，系统会优先找到 `/opt` 里的版本，而不是系统自带的版本。**因此：慎重配置 PATH 环境变量，** 既然是纯净安装+虚拟环境隔离，我们就不再需要依赖 PATH 环境变量了。

**为什么 `altinstall` 是“双保险”？**

这个 `make altinstall` 的核心逻辑是：<font color=red>不创建任何不带版本号的软链接。</font>

我们可以对比一下两者的结果：

| 安装方式        | /opt/python3.12/bin/ 下生成的文件             | 是否会生成全局软链接          |
| --------------- | --------------------------------------------- | ----------------------------- |
| make install    | 包含软链接 python3, python3.12, pip3, pip3.12 | 可能会尝试 创建全局 python3   |
| make altinstall | 只有源文件 python3.12, pip3.12                | 绝对不会 创建任何全局 python3 |

------

### 3.5. 环境配置与使用

由于安装在 `/opt`，系统默认找不到这个命令。你有两种科学的使用方式：

**方式 A：直接调用（推荐用于创建虚拟环境）**

这是最干净的方式，不需要修改系统变量。

```bash
[root@almalinux /tmp/Python-3.12.0]# /opt/python3.12/bin/python3.12 --version
```

**方式 B：配置PATH（可选）**

如果你希望在任何地方直接输入 `python3.12` 就能用：

```bash
[root@almalinux /tmp/Python-3.12.0]# sudo ln -s /opt/python3.12 /opt/python
[root@almalinux /tmp/Python-3.12.0]# tree /opt -L 1
[root@almalinux /tmp/Python-3.12.0]# vim ~/.bashrc
=====================================================================================
# config python PATH
export PATH="/opt/python/bin:$PATH"
=====================================================================================
[root@almalinux /tmp/Python-3.12.0]# exec bash
[root@almalinux /tmp/Python-3.12.0]# type python3.12
python3.12 is /opt/python/bin/python3.12
```

------

### 3.6. 结合 Ansible 流程：创建基于 /opt 的虚拟环境

现在，你可以利用位于 `/opt` 的 Python 引擎，为你的 **1G/50G 服务器** 运维项目创建一个专属的虚拟环境：

```bash
# 1. 使用 /opt 路径下的 Python 创建虚拟环境
[root@almalinux /tmp/Python-3.12.0]# cd ~
[root@almalinux ~]# /opt/python3.12/bin/python3.12 -m venv ~/ansible-project/venv

# 2. 激活虚拟环境
[root@almalinux ~]# source ~/ansible-project/venv/bin/activate
=====================================================================================
(venv) [root@almalinux ~]# type pip
pip is /root/ansible-project/venv/bin/pip
(venv) [root@almalinux ~]# type pip3
pip3 is /root/ansible-project/venv/bin/pip3
(venv) [root@almalinux ~]# ll /root/ansible-project/venv/bin
total 36
-rw-r--r-- 1 root root 9033 Jan 14 15:32 Activate.ps1
-rw-r--r-- 1 root root 2330 Jan 14 15:32 activate
-rw-r--r-- 1 root root  920 Jan 14 15:32 activate.csh
-rw-r--r-- 1 root root 2199 Jan 14 15:32 activate.fish
-rwxr-xr-x 1 root root  246 Jan 14 15:32 pip
-rwxr-xr-x 1 root root  246 Jan 14 15:32 pip3
-rwxr-xr-x 1 root root  246 Jan 14 15:32 pip3.12
lrwxrwxrwx 1 root root   10 Jan 14 15:32 python -> python3.12
lrwxrwxrwx 1 root root   10 Jan 14 15:32 python3 -> python3.12
lrwxrwxrwx 1 root root   30 Jan 14 15:32 python3.12 -> /opt/python3.12/bin/python3.12
=====================================================================================

# 3. 在虚拟环境中安装 Ansible
(venv) [root@almalinux ~]# pip config set global.index-url https://mirrors.aliyun.com/pypi/simple
Writing to /root/.config/pip/pip.conf
(venv) [root@almalinux ~]# pip config set install.trusted-host mirrors.aliyun.com
Writing to /root/.config/pip/pip.conf
(venv) [root@almalinux ~]# python3 -m pip install --upgrade pip
(venv) [root@almalinux ~]# python3 -m pip install ansible-core==2.19
(venv) [root@almalinux ~]# ansible --version
ansible [core 2.19.0]
  config file = None
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /root/ansible-project/venv/lib/python3.12/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /root/ansible-project/venv/bin/ansible
  python version = 3.12.0 (main, Jan 14 2026, 14:51:38) [GCC 11.5.0 20240719 (Red Hat 11.5.0-11)] (/root/ansible-project/venv/bin/python3)
  jinja version = 3.1.6
  pyyaml version = 6.0.3 (with libyaml v0.2.5)

# 4. 退出虚拟环境
(venv) [root@almalinux ~]# deactivate
[root@almalinux ~]#
```

------

### 3.7. 维护与清理

- **如果你想升级 Python**：只需要重复上述过程，将 `--prefix` 改为 `/opt/python3.13`，这样新老版本可以完美共存，互不干扰。
- **如果你想彻底卸载**：只需要一行命令 `sudo rm -rf /opt/python3.12`，系统干净如初。

------

**💡 为什么对于管理 1G 内存的目标机，这样做最“科学”？**

1. **确定性**：你明确知道管理机使用的 Python 版本和库，排除了 AlmaLinux 系统升级带来的潜在干扰。
2. **安全性**：`/opt` 目录通常权限控制较严，适合存放生产环境的工具链。
3. **高性能控制端**：在管理机上编译优化的 Python 会让 Ansible 解析剧本、生成任务模板的速度达到最快，从而减少管理机自身的 CPU 抖动。

**现在你的 Python 已经在 `/opt` 中安家了。我们需要基于这个环境，再次运行你的日志优化 `site.yml` 剧本吗？**



## 4.编写剧本

好的，现在再把剧本角色流程走一遍



既然你的管理机（AlmaLinux）已经通过 `/opt` 目录手动编译安装了 Python 3.12，并且环境已经完全就绪，我们现在把所有的环节——**环境激活、项目结构、角色逻辑、总调度剧本**——串联起来，进行最后一次“通电测试”。

------

### 4.1.环境激活与工具安装

在 AlmaLinux 管理机上，使用你编译好的 Python 引擎启动：

```bash
# 1. 创建存放 Ansible 项目的目录
[root@almalinux ~]# git clone git@github.com:QianSong1/ansible-palybook.git

# 2. 激活环境并验证 Ansible
[root@almalinux ~]# source ~/ansible-project/venv/bin/activate
(venv) [root@almalinux ~]# ansible --version
ansible [core 2.19.0]
  config file = None
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /root/ansible-project/venv/lib/python3.12/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /root/ansible-project/venv/bin/ansible
  python version = 3.12.0 (main, Jan 14 2026, 14:51:38) [GCC 11.5.0 20240719 (Red Hat 11.5.0-11)] (/root/ansible-project/venv/bin/python3)
  jinja version = 3.1.6
  pyyaml version = 6.0.3 (with libyaml v0.2.5)
```

------

### 4.2.角色化项目结构

构建一个标准的、可复用的 Ansible 项目布局：

```bash
# 创建角色目录
(venv) [root@almalinux ~]# cd ansible-palybook/
(venv) [root@almalinux ~/ansible-palybook]# ll
total 40
drwxr-xr-x 3 root root    66 Jan 14 16:07 00-common-template
drwxr-xr-x 3 root root    70 Jan 14 16:07 01-setup-starship-shell-prompt
-rw-r--r-- 1 root root 35149 Jan 14 16:07 LICENSE
-rw-r--r-- 1 root root    69 Jan 14 16:07 README.md
(venv) [root@almalinux ~/ansible-palybook]# cp -r 00-common-template 02-journald-log-optimize
(venv) [root@almalinux ~/ansible-palybook]# ll
total 40
drwxr-xr-x 3 root root    66 Jan 14 16:07 00-common-template
drwxr-xr-x 3 root root    70 Jan 14 16:07 01-setup-starship-shell-prompt
drwxr-xr-x 3 root root    66 Jan 14 16:11 02-journald-log-optimize
-rw-r--r-- 1 root root 35149 Jan 14 16:07 LICENSE
-rw-r--r-- 1 root root    69 Jan 14 16:07 README.md

# 创建主机清单和入口剧本
(venv) [root@almalinux ~/ansible-palybook]# cd 02-journald-log-optimize/
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# vim hosts
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# cat hosts
=====================================================================================
#分组配置
[log_server]
192.168.44.201
=====================================================================================

(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# vim site.yaml
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# cat site.yaml
=====================================================================================
---
# 这是一个优化系统systemd日志的剧本

- name: 优化系统systemd日志
  hosts:
    - log_server
  remote_user: root

  roles:
    - journald_optimize
=====================================================================================

# 创建角色并删除多余的角色
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# ll roles/
total 0
drwxr-xr-x 12 root root 162 Jan 14 16:11 common
drwxr-xr-x 12 root root 162 Jan 14 16:11 nginx
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# cp -r roles/common roles/journald_optimize
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# ll roles/
total 0
drwxr-xr-x 12 root root 162 Jan 14 16:11 common
drwxr-xr-x 12 root root 162 Jan 14 16:18 journald_optimize
drwxr-xr-x 12 root root 162 Jan 14 16:11 nginx
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# rm -rf roles/nginx
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# ll roles/
total 0
drwxr-xr-x 12 root root 162 Jan 14 16:11 common
drwxr-xr-x 12 root root 162 Jan 14 16:18 journald_optimize
```

------

### 4.3.填充代码内容（1G内存/50G磁盘优化版）

**1. 定义默认变量 (`roles/journald_optimize/defaults/main.yaml`)**

```bash
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# vim roles/journald_optimize/defaults/main.yaml
---
# 科学配置：1G内存/50G磁盘
journal_storage: "persistent"        # 日志保存在磁盘
journal_system_max_use: "500M"       # 限制最大使用磁盘 500M
journal_system_maxfile_size: "50M"   # 限制单个日志文件大小 50M
journal_system_keep_free: "5G"       # 预留 5G 磁盘空间
journal_runtime_max_use: "64M"       # 限制最大使用内存 64M
journal_runtime_maxfile_size: "16M"  # 限制内存中单个日志文件大小 16M
journal_max_retention_sec: "1month"  # 日志最多保留1个月
journal_rate_limit_interval: "30s"   # 限制磁盘刷写频率
journal_rate_limit_burst: 2000
```

**2. 编写 Jinja2 模板 (`roles/journald_optimize/templates/journald.conf.j2`)**

```bash
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# vim roles/journald_optimize/templates/journald.conf.j2
# 由 AlmaLinux 管理机上的 Ansible 自动生成
[Journal]
# --- 持久化存储设置 (针对磁盘 /var/log/journal) ---

# 建议设为 persistent，将日志持久化到硬盘 (/var/log/journal)
Storage={{ journal_storage }}

# 开启压缩，节省磁盘空间
Compress=yes

# 磁盘最大占用：建议 500M。
# 50G 磁盘虽然不小，但日志属于次要数据，不应占用过多。
SystemMaxUse={{ journal_system_max_use }}

# 单个日志文件最大大小：建议 50M。
# 这样可以保证日志轮转更频繁，方便按需清理。
SystemMaxFileSize={{ journal_system_maxfile_size }}

# 磁盘最少保留空间：建议 5G。
# 确保日志增长不会导致磁盘完全写满，保留给系统运行使用。
SystemKeepFree={{ journal_system_keep_free }}

# 内存最大占用（运行时日志）：建议 64M。
# 您只有 1G 内存，这里一定要严格限制，防止 journald 占用过多系统缓存。
RuntimeMaxUse={{ journal_runtime_max_use }}

# 运行时单个日志最大大小
RuntimeMaxFileSize={{ journal_runtime_maxfile_size }}

# 日志最长保存时间：建议 1month (1个月)。
# 除非有合规需求，否则过旧的日志参考价值不大。
MaxRetentionSec={{ journal_max_retention_sec }}

# 限制速率：每 30 秒内最多记录 2000 条日志。
# 防止某个服务故障刷屏导致 CPU 和 IO 飙升。
RateLimitIntervalSec={{ journal_rate_limit_interval }}
RateLimitBurst={{ journal_rate_limit_burst }}
```

**3. 编写核心任务 (`roles/journald_optimize/tasks/main.yaml`)**

```bash
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# vim roles/journald_optimize/tasks/main.yaml
---
# 优化systemd日志具体任务

- name: "【步骤 1】创建持久化目录 /var/log/journal 并授权"
  ansible.builtin.file:
    path: /var/log/journal
    state: directory
    owner: root
    group: systemd-journal
    mode: "2755"

- name: "【步骤 2】关键调用系统命令修复目录 /var/log/journal 权限"
  ansible.builtin.shell:
    cmd: "systemd-tmpfiles --create --prefix /var/log/journal"

- name: "【步骤 3】同步优化配置模板"
  ansible.builtin.template:
    src: journald.conf.j2
    dest: /etc/systemd/journald.conf
    owner: root
    group: root
    mode: "0644"
    backup: yes
  notify:
    - "重启journald服务"
    - "手动刷盘"

- name: "【步骤 4】强制立即执行变更"
  ansible.builtin.meta: flush_handlers

- name: "【步骤 5】究极保险重启journald服务"
  ansible.builtin.systemd:
    name: systemd-journald
    state: restarted
```

**4. 编写处理程序 (`roles/journald_optimize/handlers/main.yaml`)**

```bash
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# vim roles/journald_optimize/handlers/main.yaml
---
# 任务的触发处理程序，需要注意name要与任务的notify清单一致

- name: "重启journald服务"
  ansible.builtin.systemd:
    name: systemd-journald
    state: restarted

- name: "手动刷盘"
  ansible.builtin.shell: "journalctl --flush"
```

------

### 4.4.总调度配置

**1. 主机清单 (`hosts`)**

```bash
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# cat hosts
#分组配置,替换为你的具体IP地址
[log_server]
192.168.44.201
```

**2. 入口剧本 (`site.yml`)**

```bash
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# cat site.yaml
---
# 这是一个优化系统systemd日志的剧本

- name: 优化系统systemd日志
  hosts:
    - log_server
  remote_user: root

  roles:
    - journald_optimize
```

------

### 4.5.一键运行与终极检查

**1.配置免密登录**

```bash
#创建主机清单
cd ~
cat >host_list.txt <<'EOF'
192.168.44.201 1
EOF

#配置免密登录
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -y
yum install -y sshpass
cd ~
host_list=()
while IFS=$'\n' read -r line; do
    if [ "${#line}" -gt 0 ]; then
        host_list+=("${line}")
    fi
done <"host_list.txt"
for i in "${host_list[@]}"; do
    host_ip="$(echo "${i}" | awk '{print $1}')"
    host_password="$(echo "${i}" | awk '{print $2}')"
    echo "start config host：${host_ip}"
    sshpass -p"${host_password}" ssh-copy-id "-o StrictHostKeyChecking=no" -i /root/.ssh/id_rsa.pub root@"${host_ip}"
    echo -e "\033[36m===================================================\033[0m"
    echo -e "\033[36m${host_ip}\033[0m"
    echo -e "\033[36m===================================================\033[0m"
    echo
done

#验证
ssh root@192.168.44.201 "ip a"
```

**2. 执行剧本**

```bash
# 确保在虚拟环境下执行
[root@almalinux ~/ansible-palybook/02-journald-log-optimize]# source ~/ansible-project/venv/bin/activate
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]#

# 验证主机清单
ansible -i hosts all --list-hosts

# 列出剧本任务列表
ansible-playbook -i hosts --list-tasks site.yaml

# 检查语法
ansible-playbook -i hosts --syntax-check site.yaml

# 模拟执行剧本
ansible-playbook -i hosts -C site.yaml

# 执行剧本
ansible-playbook -i hosts site.yaml
```

**3. 科学验证 (Ad-hoc 方式)**

利用 Ansible 的强大功能进行批量核验：

- **检查磁盘持久化位置**： `ansible log_server -i hosts -m ansible.builtin.shell -a "journalctl --disk-usage"` *(输出应显示在 /var/log/journal 目录下)*
- **检查配置文件中的内存限制**： `ansible log_server -i hosts -m ansible.builtin.shell -a "grep -i 'RuntimeMaxUse' /etc/systemd/journald.conf"` *(输出应显示 100M)*
- **检查生效的配置参数：**`ansible log_server -i hosts -m ansible.builtin.shell -a "journalctl -u systemd-journald | grep -Ei '(/run/log/jour|/var/log/jour)'"`*(输出应显示 各种日志的配额，与你的配置一致才对，证明生效)*

**4.退出虚拟环境**

```bash
#执行命令deactivate即可退出Python虚拟环境，即(venv)标识不复存在
(venv) [root@almalinux ~/ansible-palybook/02-journald-log-optimize]# deactivate
[root@almalinux ~/ansible-palybook/02-journald-log-optimize]#
```

------

## 5.总结

你现在的架构已经非常稳健：

1. **管理机 (AlmaLinux)**：拥有独立的 Python 3.12 编译环境（`/opt`）和隔离的虚拟环境。
2. **目标机 (1G/50G)**：通过 Ansible 角色实现了资源的极致优化。
3. **持久化**：解决了最初提到的日志文件不生成的问题。

**既然你的自动化体系已经完全打通，是否需要我为你增加一个「每日自动清理过时日志」的 Cron 任务剧本，让这台 50G 的服务器永远保持清爽？**
