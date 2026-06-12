# 宝宝日记

记录宝宝成长点滴的家庭私有 App，支持 Android、Linux 桌面和 Web。

## 功能

- **日记**：记录每日文字、心情、照片和视频，支持搜索和日期筛选
- **成长里程碑**：按类别（运动、语言、社交、认知）记录重要时刻
- **评论**：家庭成员可以在日记和里程碑下互相留言
- **宝宝档案**：保存姓名、生日、身高体重，自动计算月龄
- **局域网同步**：通过自建 PocketBase 服务器，在家庭设备间实时同步数据、照片和视频

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter + Material 3 |
| 状态管理 | Riverpod |
| 本地数据库 | Drift (SQLite) |
| 同步后端 | PocketBase |
| 导航 | go_router |

## 运行

```bash
# 安装依赖
flutter pub get

# 运行（Android / Linux / Web）
flutter run
```

需要 Flutter SDK ≥ 3.12。

## 同步设置

同步基于局域网自建 [PocketBase](https://pocketbase.io/)，无需公网服务器。

**1. 启动 PocketBase**

```bash
./pocketbase serve --http=0.0.0.0:2363
```

**2. 初始化数据库集合**

在 App 设置页 → 局域网同步 → 展开"首次初始化服务器"，填入管理员账号后点击"初始化集合"，自动创建所需的数据表。

**3. 连接**

在设置页填入服务器地址（如 `http://192.168.1.100:2363`），点击"连接"即可。家里其他设备填同一地址，数据自动双向同步。

## Web 部署

Web 版可同时部署到本地 PocketBase 的静态目录和 Vercel：

```bash
bash deploy_web.sh
```

脚本会构建 Web 产物，分别拷贝到 PocketBase `pb_public/` 目录并发布到 Vercel。
