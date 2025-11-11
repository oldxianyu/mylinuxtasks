# mylinuxtasks

## 自己摸索的 Linux 一些简化操作

---
### GitHub 加速站
使用地址：  
```
github.502211.xyz
```
---
### wg_ui_manage.sh
一键安装或卸载 WireGuard。  
当前适配系统为 **Ubuntu 22**，其他系统请自行测试。

### 一键安装 WireGuard + Web UI
bash <(wget -qO- https://raw.githubusercontent.com/oldxianyu/mylinuxtasks/main/wg_ui_manage.sh)
### 国内加速版
bash <(wget -qO- https://github.502211.xyz/https://raw.githubusercontent.com/oldxianyu/mylinuxtasks/main/wg_ui_manage.sh)

---

### install_file_server.sh
一键生成简易文件下载站（Docker 版本）。  
适用于已安装 Docker 的系统，推荐环境为 **飞牛 NAS（Ubuntu 22）**。

### 一键安装 file_server
bash <(wget -qO- https://raw.githubusercontent.com/oldxianyu/mylinuxtasks/main/install_file_server.sh)
### 国内加速版
bash <(wget -qO- https://github.502211.xyz/https://raw.githubusercontent.com/oldxianyu/mylinuxtasks/main/install_file_server.sh)

#### 默认参数
```
PORT=9002
SERVER_NAME="file-server"
WORK_DIR="/vol1/1000/work"
TITLE="xianyu下载站"
```

#### 可自定义项
1. 修改映射端口（PORT）  
2. 修改 Docker 容器名称（SERVER_NAME）  
3. 修改文件存储目录（WORK_DIR）  
4. 修改网站显示标题（TITLE）

#### 使用说明
1. 运行脚本前请确保系统已安装 Docker。  
2. 执行脚本后会自动启动文件下载站。  
3. 启动成功后，可通过浏览器或命令行访问：  
   ```
   http://<你的域名或IP>:<端口>/
   ```
4. Linux 用户可直接使用 `wget` 下载文件，例如：  
   ```
   wget http://allin1.cn:9002/文件名
   ```

---

### 目录说明
- `wg_ui_manage.sh`：WireGuard 管理脚本  
- `install_file_server.sh`：Docker 文件下载站生成脚本  
- 其他脚本：后续扩展的系统自动化工具
