# 用户管理工具

安全的用户账户管理工具，用于管理存储在腾讯云COS中的用户数据。使用Shell脚本实现，轻量级且易于维护。

## 🔐 安全特性

- **环境变量认证**: 通过环境变量获取COS访问凭证，避免硬编码
- **密码安全输入**: 使用终端安全输入，密码不会显示在屏幕上
- **SHA256加密**: 密码使用SHA256哈希存储，不保存明文
- **COS存储**: 用户数据安全存储在私有COS桶中

## 📋 环境变量要求

使用前需要设置以下环境变量：

```bash
export COS_DATA_BUCKET="your-data-bucket-name"
export COS_REGION="ap-guangzhou"
export COS_SECRET_ID="your-secret-id"
export COS_SECRET_KEY="your-secret-key"
```

### 🔑 如何获取腾讯云访问凭证

#### 1. 获取 COS_SECRET_ID 和 COS_SECRET_KEY

1. **登录腾讯云控制台**
   - 访问 [腾讯云控制台](https://console.cloud.tencent.com/)
   - 使用您的腾讯云账号登录

2. **进入访问管理页面**
   - 在控制台顶部搜索框输入"访问管理"或"CAM"
   - 点击进入"访问管理 CAM"服务

3. **创建API密钥**
   - 在左侧菜单选择"访问密钥" → "API密钥管理"
   - 点击"新建密钥"按钮
   - 系统会生成一对密钥：
     - `SecretId` → 对应 `COS_SECRET_ID`
     - `SecretKey` → 对应 `COS_SECRET_KEY`
   - **重要**: 请立即保存SecretKey，页面关闭后无法再次查看

4. **设置权限（可选但推荐）**
   - 为了安全，建议创建子用户并只授予COS相关权限
   - 在"用户" → "用户列表"中创建新用户
   - 为用户分配"QcloudCOSFullAccess"策略
   - 使用子用户的密钥而不是主账号密钥

#### 2. 获取 COS_DATA_BUCKET 和 COS_REGION

1. **查看COS桶信息**
   - 在腾讯云控制台搜索"对象存储"或"COS"
   - 进入"对象存储 COS"服务

2. **找到数据桶名称**
   - 在存储桶列表中找到用于存储用户数据的桶
   - 桶名称格式通常为：`bucket-name-appid`
   - 例如：`oh-i-have-that-data-1234567890`

3. **确认地域信息**
   - 在桶列表中可以看到每个桶的所属地域
   - 常用地域代码：
     - `ap-guangzhou` - 广州
     - `ap-shanghai` - 上海  
     - `ap-beijing` - 北京
     - `ap-chengdu` - 成都

#### 3. 配置示例

根据您的实际信息，配置应该类似：

```bash
# 示例配置
export COS_DATA_BUCKET="oh-i-have-that-data-1234567890"
export COS_REGION="ap-guangzhou"
export COS_SECRET_ID="your-secret-id-here"
export COS_SECRET_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

#### 4. 验证配置

可以使用以下命令验证配置是否正确：

```bash
# 检查环境变量是否设置
echo "桶名称: $COS_DATA_BUCKET"
echo "地域: $COS_REGION"
echo "密钥ID: ${COS_SECRET_ID:0:8}..."
echo "密钥Key: ${COS_SECRET_KEY:0:8}..."

# 测试COS访问（需要先运行 ./user_manager.sh init）
./user_manager.sh list
```

## 🚀 安装和使用

### 1. 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# macOS
brew install curl jq
```

### 2. 设置执行权限

```bash
chmod +x user_manager.sh setup.sh
```

### 3. 初始化用户数据文件

```bash
./user_manager.sh init
```

### 4. 添加用户

```bash
./user_manager.sh add
```

交互式输入用户信息：
- 邮箱地址
- 用户姓名  
- 用户角色 (admin/user)
- 密码 (安全输入，不显示)

### 5. 列出所有用户

```bash
./user_manager.sh list
```

## 📁 数据存储结构

用户数据存储在COS的 `auth/users.json` 文件中，结构如下：

```json
[
  {
    "id": "admin",
    "email": "admin@example.com",
    "password": "sha256_hash_value",
    "role": "admin",
    "name": "系统管理员",
    "active": true,
    "created": "2025-09-18 16:00:00",
    "updated": "2025-09-18 16:00:00"
  }
]
```

## 🔧 命令参考

| 命令 | 描述 | 示例 |
|------|------|------|
| `init` | 初始化用户数据文件 | `./user_manager.sh init` |
| `list` | 列出所有用户 | `./user_manager.sh list` |
| `add` | 添加新用户 | `./user_manager.sh add` |

## 🛡️ 安全最佳实践

1. **环境变量管理**
   ```bash
   # 使用 .env 文件 (不要提交到Git)
   source .env
   
   # 或者临时设置
   export COS_SECRET_ID="your-secret-id"
   export COS_SECRET_KEY="your-secret-key"
   ```

2. **访问权限控制**
   - 确保COS数据桶设置为私有访问
   - 使用最小权限原则配置访问密钥
   - 定期轮换访问密钥

3. **密码策略**
   - 使用强密码
   - 定期更新密码
   - 不要在命令行历史中留下密码痕迹

## 🔍 故障排除

### 常见错误

1. **环境变量未设置**
   ```
   错误: 缺少必要的环境变量: COS_DATA_BUCKET, COS_REGION, COS_SECRET_ID, COS_SECRET_KEY
   ```
   解决: 检查并设置所有必需的环境变量

2. **依赖工具未安装**
   ```
   错误: 缺少必要的依赖: curl jq
   ```
   解决: 安装curl和jq工具

3. **用户文件不存在**
   ```
   暂无用户数据
   ```
   解决: 运行 `./user_manager.sh init` 初始化用户数据文件

## 📝 开发说明

### 依赖工具

- `curl` - HTTP客户端，用于COS API调用
- `jq` - JSON处理工具
- `shasum` - SHA256哈希计算

### 扩展功能

可以根据需要添加以下功能：
- 批量导入用户
- 用户权限细分
- 操作日志记录
- 数据备份和恢复
- 完整的COS签名算法实现