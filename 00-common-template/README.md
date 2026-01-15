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

