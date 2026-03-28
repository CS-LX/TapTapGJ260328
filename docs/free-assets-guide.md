# 免费素材下载与使用指南

> AI 助手在沙盒环境中下载和使用免费素材的操作手册。
> 所有下载均需通过代理 `http://127.0.0.1:1080`。

---

## 环境前提

```bash
# 可用工具
curl / wget / unzip / tar

# 代理配置（所有网络请求必须加）
PROXY="--proxy http://127.0.0.1:1080"
# 或
export http_proxy=http://127.0.0.1:1080
export https_proxy=http://127.0.0.1:1080

# 素材存放目录
/workspace/assets/          # 游戏资源根目录（引擎自动识别）
/workspace/assets/Textures/ # 贴图
/workspace/assets/Sounds/   # 音效
/workspace/assets/Fonts/    # 字体
/workspace/assets/Models/   # 3D 模型（如果需要）
```

---

## 1. Kenney.nl -- 游戏素材（最推荐）

### 概览

| 项目 | 说明 |
|------|------|
| 网址 | https://kenney.nl/assets |
| 协议 | **CC0**（完全免费，商用无需署名） |
| 登录 | **不需要** |
| 素材量 | 232 个素材包（111 个 2D + 91 个 3D + 30 个音频） |
| 文件格式 | ZIP 压缩包 |

### 下载方式

#### 方式一：直接下载 ZIP（推荐）

```bash
# URL 格式：https://kenney.nl/data/assets/{slug}.zip
# slug 就是素材页面路径中的名称

# 下载 2D 平台跳跃素材包
curl --proxy http://127.0.0.1:1080 -L -o /tmp/platformer.zip \
  https://kenney.nl/data/assets/simplified-platformer-pack.zip

# 解压到 assets 目录
unzip -o /tmp/platformer.zip -d /workspace/assets/
rm /tmp/platformer.zip
```

#### 方式二：从 GitHub 获取单个文件

```bash
# GitHub 仓库：https://github.com/kenneyNL/kenney-assets
# 包含 127 个素材包（网站子集）
# 单文件下载 URL 格式：
# https://raw.githubusercontent.com/kenneyNL/kenney-assets/main/www.kenney.nl/Assets/{slug}/{path}

# 只下载一个 3D 模型
curl --proxy http://127.0.0.1:1080 -L -o /workspace/assets/Models/ambulance.glb \
  https://raw.githubusercontent.com/kenneyNL/kenney-assets/main/www.kenney.nl/Assets/car-pack/Models/ambulance.glb

# 用 GitHub API 列出素材包内容
curl --proxy http://127.0.0.1:1080 -s \
  'https://api.github.com/repos/kenneyNL/kenney-assets/contents/www.kenney.nl/Assets/{slug}' \
  | python3 -c "import sys,json; [print(i['name']) for i in json.load(sys.stdin)]"
```

### ZIP 内部结构

**2D 素材包**：
```
{Pack Name}/
├── Tiles/          # 单个 PNG 切图（tile_0000.png, tile_0001.png...）
├── Spritesheet/    # 精灵图合集（sheet.png + sheet.xml 坐标数据）
├── Tilemap/        # Tiled 地图编辑器文件（.tmx, 部分有）
└── License.txt     # CC0 许可证
```

**3D 素材包**：
```
{Pack Name}/
├── Models/         # GLB 格式 3D 模型（glTF Binary）
└── License.txt
```

**音频素材包**：
```
{Pack Name}/
├── *.ogg / *.wav   # 音频文件
└── License.txt
```

### 常用素材包速查

#### 2D 素材

| 素材包 slug | 说明 | 大小 |
|------------|------|------|
| `simplified-platformer-pack` | 简化版平台跳跃瓦片 | 304KB |
| `pixel-platformer` | 像素风平台跳跃 | 小 |
| `micro-roguelike` | 微型 Roguelike 瓦片 | 42KB |
| `space-shooter-redux` | 太空射击素材 | - |
| `racing-pack` | 赛车俯视图素材 | - |
| `ui-pack` | UI 界面元素 | - |
| `ui-pack-rpg-expansion` | RPG 风格 UI | - |
| `game-icons` | 通用游戏图标 | - |
| `game-icons-expansion` | 游戏图标扩展 | - |
| `onscreen-controls` | 虚拟摇杆/按钮 | - |
| `crosshair-pack` | 准心/瞄准器 | - |
| `emotes-pack` | 表情气泡 | - |
| `kenney-fonts` | 免费字体 | - |

#### 3D 素材

| 素材包 slug | 说明 | 格式 |
|------------|------|------|
| `car-pack` | 车辆模型 (100个) | GLB |
| `nature-kit` | 自然场景套件 | GLB |
| `castle-kit` | 城堡套件 | GLB |
| `space-kit` | 太空场景套件 | GLB |
| `prototype-kit` | 原型开发套件 | GLB |
| `survival-kit` | 生存游戏套件 | GLB |
| `furniture-kit` | 家具套件 | GLB |
| `food-kit` | 食物模型 | GLB |
| `farm-animals` | 农场动物 | GLB |
| `modular-characters` | 可组合角色 | GLB |
| `traffic` | 交通车辆 | GLB |

#### 音频素材

| 素材包 slug | 说明 |
|------------|------|
| `interface-sounds` | UI 界面音效 |
| `impact-sounds` | 碰撞/打击音效 |
| `rpg-audio` | RPG 游戏音效 |
| `sci-fi-sounds` | 科幻音效 |
| `ui-audio` | UI 操作音效 |
| `music-jingles` | 短音乐片段 |
| `digital-audio` | 数字/电子音效 |

### 在 UrhoX 中使用

```lua
-- 2D 纹理：解压后的 PNG 文件放入 assets/Textures/
local texture = cache:GetResource("Texture2D", "Textures/tile_0000.png")

-- 2D 精灵图（Spritesheet）
local spriteSheet = cache:GetResource("SpriteSheet2D", "Textures/sheet.xml")

-- 音效：解压后的 OGG 文件放入 assets/Sounds/
local sound = cache:GetResource("Sound", "Sounds/click.ogg")

-- 3D 模型需要格式转换（UrhoX 使用 .mdl 格式，不直接支持 .glb）
-- 建议使用引擎内置模型或 search_3d_resource 工具
```

---

## 2. 猫啃网 (maoken.com) -- 中文免费字体

### 概览

| 项目 | 说明 |
|------|------|
| 网址 | https://www.maoken.com/ |
| 类型 | 中文免费字体聚合平台 |
| 登录 | **不需要** |
| 字体数量 | **409** 款 |
| 托管方式 | 猫啃网本身不托管字体，提供外链跳转（~95% GitHub） |

### 下载流程

#### Step 1: 搜索字体

```bash
# 搜索关键字
curl --proxy http://127.0.0.1:1080 -s -L \
  'https://www.maoken.com/?s=得意黑' \
  | grep -oP 'href="https://www.maoken.com/freefonts/[0-9]+\.html"[^>]*>[^<]+' | head -5
```

#### Step 2: 提取 GitHub 下载链接

```bash
# 从字体页面提取下载链接
curl --proxy http://127.0.0.1:1080 -s -L \
  'https://www.maoken.com/freefonts/{ID}.html' \
  | grep '字体下载' | grep -oP 'href="[^"]+"'
```

#### Step 3: 通过 GitHub API 获取最新版本

```bash
# 获取最新 release 的下载链接
curl --proxy http://127.0.0.1:1080 -s \
  'https://api.github.com/repos/{org}/{repo}/releases/latest' \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    print(f\"{asset['name']} ({asset['size']/1024/1024:.1f}MB): {asset['browser_download_url']}\")
"
```

#### Step 4: 下载并安装

```bash
# 下载 ZIP
curl --proxy http://127.0.0.1:1080 -L -o /tmp/font.zip \
  'https://github.com/{org}/{repo}/releases/download/{tag}/{file}.zip'

# 解压提取 TTF/OTF
unzip -j /tmp/font.zip '*.ttf' '*.otf' -d /workspace/assets/Fonts/
rm /tmp/font.zip
```

### 常用一键下载命令

```bash
# 得意黑 Smiley Sans（活泼黑体，适合休闲游戏）
curl --proxy http://127.0.0.1:1080 -L -o /tmp/smiley.zip \
  https://github.com/atelier-anchor/smiley-sans/releases/download/v2.0.1/smiley-sans-v2.0.1.zip
unzip -j /tmp/smiley.zip '*.ttf' -d /workspace/assets/Fonts/ && rm /tmp/smiley.zip

# 霞鹜文楷 LXGW WenKai（优雅楷体，适合中国风/RPG）- 注意较大 ~61MB
curl --proxy http://127.0.0.1:1080 -L -o /tmp/wenkai.zip \
  https://github.com/lxgw/LxgwWenKai/releases/download/v1.501/lxgw-wenkai-v1.501.zip
unzip -j /tmp/wenkai.zip '*.ttf' -d /workspace/assets/Fonts/ && rm /tmp/wenkai.zip
```

### 推荐游戏字体

| 字体 | 页面 ID | 风格 | 大小 | 适用场景 | 一键下载可用 |
|------|---------|------|------|---------|------------|
| 得意黑 Smiley Sans | 15849 | 活泼黑体 | 5.4MB TTF | 休闲游戏、UI 标题 | 是 |
| 霞鹜文楷 LXGW WenKai | 8702 | 优雅楷体 | ~61MB | RPG、文字冒险、中国风 | 是 |
| 思源黑体 Noto Sans CJK | 62 | 标准黑体 | 大 | 通用 UI、正文 | 是 |
| 思源宋体 Noto Serif CJK | 135 | 标准宋体 | 大 | 叙事、古风 | 是 |
| 小赖字体 XiaolaiFont | 5423 | 圆润手写 | - | 休闲、儿童游戏 | 是 |
| 悠哉字体 Yozai | 14854 | 手写圆润 | - | 休闲游戏 | 是 |
| 阿里巴巴普惠体 | 254 | 商务黑体 | - | 正式 UI | 官网下载 |

### 在 UrhoX 中使用

```lua
-- 字体放在 assets/Fonts/ 目录下
-- NanoVG 使用
local font = nvgCreateFont(vg, "smiley", "Fonts/SmileySans.ttf")
nvgFontFace(vg, "smiley")
nvgFontSize(vg, 32)
nvgText(vg, 100, 100, "你好世界")

-- UI 系统使用
local UI = require("urhox-libs/UI")
UI.Init({
    fonts = {
        { family = "game", weights = { normal = "Fonts/SmileySans.ttf" } }
    },
    scale = UI.Scale.DEFAULT,
})
```

---

## 3. iconfont.cn -- 矢量图标

### 概览

| 项目 | 说明 |
|------|------|
| 网址 | https://www.iconfont.cn/ |
| 类型 | 阿里巴巴矢量图标库 |
| 登录 | 搜索 SVG **不需要**（上限 10 条），批量下载需要 |
| 图标量 | 海量 |
| 输出格式 | SVG（可获取），PNG/字体包（需登录） |

### 不登录可用的 API

#### 搜索建议

```bash
curl --proxy http://127.0.0.1:1080 -s \
  'https://www.iconfont.cn/api/suggest/search.json?q=game' \
  -H 'Referer: https://www.iconfont.cn/'
# 返回搜索关键词建议列表，支持中英文
```

#### 搜索图标并获取 SVG（核心 API）

```bash
# 搜索图标，返回完整 SVG 数据
# 参数：q=关键词（中英文均可），pageSize=1~10（硬上限 10 条，无分页）
curl --proxy http://127.0.0.1:1080 -s \
  'https://www.iconfont.cn/api/help/search.json?q=game&pageSize=10' \
  -H 'Referer: https://www.iconfont.cn/'
```

**响应字段**：

| 字段 | 说明 |
|------|------|
| `icons[].id` | 图标 ID |
| `icons[].name` | 图标名称 |
| `icons[].show_svg` | **完整 SVG 源码**（viewBox 1024x1024） |
| `icons[].unicode` | Unicode 码点 |
| `icons[].font_class` | CSS 类名 |
| `icons[].repositorie.name` | 所属图标库名称 |

#### 提取干净 SVG 的脚本

```bash
# 搜索并保存 SVG 文件
curl --proxy http://127.0.0.1:1080 -s \
  'https://www.iconfont.cn/api/help/search.json?q=heart&pageSize=1' \
  -H 'Referer: https://www.iconfont.cn/' \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
icon = data['data']['icons'][0]
svg = icon['show_svg']
# 清理 DOCTYPE
svg = svg.replace('<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">', '').strip()
print(svg)
" > /workspace/assets/Textures/heart.svg
```

### 限制

| 限制项 | 详情 |
|--------|------|
| 搜索结果上限 | 10 条，不支持分页 |
| PNG 下载 | 需要登录 |
| 字体包生成 | 需要登录 |
| 批量操作 | 需要登录 |
| SVG viewBox | 固定 1024x1024，需自行缩放 |

### 在 UrhoX 中使用

SVG 不能直接用于 UrhoX（引擎不支持 SVG 格式）。使用方式：

1. **NanoVG 直接绘制**：解析 SVG path 数据，用 NanoVG API 重绘
2. **转为 PNG 后使用**：在外部工具中将 SVG 转为 PNG（沙盒环境中不太方便）
3. **使用 generate_image 工具**：更推荐直接用 AI 生成所需图标

> **建议**：iconfont 更适合做参考，实际游戏图标建议用 `generate_image` 工具直接生成 PNG。

---

## 4. Fontspace.com -- 英文免费字体

### 概览

| 项目 | 说明 |
|------|------|
| 网址 | https://www.fontspace.com/ |
| 类型 | 免费英文字体网站 |
| 登录 | **不需要** |
| 注意 | **必须设置浏览器 User-Agent**，否则返回 403 |
| 技术架构 | Next.js SSR（数据在 `__NEXT_DATA__` JSON 中） |

### 下载流程（3 步）

```bash
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Step 1: 搜索字体
curl --proxy http://127.0.0.1:1080 -s \
  -H "User-Agent: $UA" \
  'https://www.fontspace.com/search?q=pixel' \
  | python3 -c "
import json, re, sys
html = sys.stdin.read()
m = re.search(r'<script id=\"__NEXT_DATA__\"[^>]*>(.*?)</script>', html)
data = json.loads(m.group(1))
fonts = data['props']['pageProps']['fonts']
for f in fonts[:5]:
    print(f'{f[\"name\"]:30s} slug={f.get(\"slug\",\"\")} dl={f.get(\"download_url\",\"N/A\")}')
"

# Step 2: 访问下载页，获取真实文件 URL
# download_url 格式: /get/family/{slug}
curl --proxy http://127.0.0.1:1080 -s \
  -H "User-Agent: $UA" \
  'https://www.fontspace.com/get/family/{download_slug}' \
  | python3 -c "
import json, re, sys
html = sys.stdin.read()
m = re.search(r'<script id=\"__NEXT_DATA__\"[^>]*>(.*?)</script>', html)
data = json.loads(m.group(1))
dl = data['props']['pageProps']['fontDownload']
print(dl['file'])  # 真实 CDN 下载 URL
"

# Step 3: 下载 ZIP 文件
curl --proxy http://127.0.0.1:1080 -L \
  -H "User-Agent: $UA" \
  -o /tmp/font.zip \
  'https://dl.fontspace.co/public/{id}/{slug}/{filename}.zip'

# 解压
unzip -j /tmp/font.zip '*.ttf' '*.otf' -d /workspace/assets/Fonts/
rm /tmp/font.zip
```

### 注意事项

- **User-Agent 是必须的**：不设置会被 Cloudflare 拦截返回 403
- **CDN 域名是 `dl.fontspace.co`**：与主站不同
- **ZIP 内含 license 文件**：每个 ZIP 都有 `Fontspace License Information.txt`
- **多数字体仅限个人使用**：注意检查 license 字段是否标注 "Free for commercial use"

### 在 UrhoX 中使用

```lua
-- 与猫啃网字体相同的使用方式
local font = nvgCreateFont(vg, "pixel", "Fonts/PixelEmulator.ttf")
```

---

## 5. indienova -- 游戏素材导航

### 概览

| 项目 | 说明 |
|------|------|
| 网址 | https://indienova.com/sp/gameDevResource |
| 类型 | 免费游戏素材网站**聚合导航** |
| 登录 | 不需要浏览（各外链可能有自己的要求） |

### 说明

indienova 是一个**导航页面**，汇集了大量免费游戏素材网站的链接，包括：
- 2D 素材（精灵图、瓦片图）
- 3D 模型
- 音效/音乐
- 字体
- 工具

它本身不托管素材，而是链接到各个来源。适合在需要寻找特定类型素材时浏览参考，但实际下载需要跳转到对应网站。

---

## 快速操作参考

### 场景一：游戏需要 2D 瓦片图

```bash
# 推荐：Kenney 平台跳跃素材包
curl --proxy http://127.0.0.1:1080 -L -o /tmp/tiles.zip \
  https://kenney.nl/data/assets/simplified-platformer-pack.zip
unzip -o /tmp/tiles.zip -d /workspace/assets/ && rm /tmp/tiles.zip
```

### 场景二：游戏需要中文字体

```bash
# 推荐：得意黑（活泼，5MB，适合标题和 UI）
curl --proxy http://127.0.0.1:1080 -L -o /tmp/font.zip \
  https://github.com/atelier-anchor/smiley-sans/releases/download/v2.0.1/smiley-sans-v2.0.1.zip
unzip -j /tmp/font.zip 'SmileySans.ttf' -d /workspace/assets/Fonts/ && rm /tmp/font.zip
```

### 场景三：游戏需要 UI 音效

```bash
# 推荐：Kenney Interface Sounds
curl --proxy http://127.0.0.1:1080 -L -o /tmp/sounds.zip \
  https://kenney.nl/data/assets/interface-sounds.zip
unzip -o /tmp/sounds.zip -d /workspace/assets/ && rm /tmp/sounds.zip
```

### 场景四：需要简单图标 SVG

```bash
# 从 iconfont 搜索（最多 10 个结果）
curl --proxy http://127.0.0.1:1080 -s \
  'https://www.iconfont.cn/api/help/search.json?q=home&pageSize=1' \
  -H 'Referer: https://www.iconfont.cn/' \
  | python3 -c "
import json, sys
icon = json.load(sys.stdin)['data']['icons'][0]
svg = icon['show_svg'].replace('<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">', '').strip()
with open('/workspace/assets/Textures/home.svg', 'w') as f:
    f.write(svg)
print(f'Saved: {icon[\"name\"]} ({len(svg)} bytes)')
"
```

### 场景五：需要英文像素字体

```bash
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
# 已知的 Pixel Emulator 字体直接下载
curl --proxy http://127.0.0.1:1080 -L \
  -H "User-Agent: $UA" \
  -o /tmp/pixel-font.zip \
  'https://dl.fontspace.co/public/21507/yqm0o/pixel-emulator-font-21507.zip'
unzip -j /tmp/pixel-font.zip '*.ttf' -d /workspace/assets/Fonts/ && rm /tmp/pixel-font.zip
```

---

## 综合对比

| 网站 | 类型 | 需登录 | 推荐度 | 适用场景 |
|------|------|--------|--------|---------|
| **Kenney.nl** | 游戏素材 | 否 | ★★★★★ | 2D/3D/音效，首选 |
| **猫啃网** | 中文字体 | 否 | ★★★★★ | 中文游戏字体，首选 |
| **iconfont.cn** | 矢量图标 | 部分 | ★★★☆☆ | 简单图标参考（上限10条） |
| **Fontspace.com** | 英文字体 | 否 | ★★★★☆ | 英文/像素字体 |
| **indienova** | 素材导航 | - | ★★★☆☆ | 发现新素材来源 |

---

## 注意事项

1. **素材许可证**：Kenney 是 CC0（完全自由），猫啃网字体多为 SIL OFL（免费商用），Fontspace 需逐个检查
2. **文件大小**：中文字体通常较大（5~60MB），下载前注意空间
3. **格式兼容**：UrhoX 支持 PNG/JPG（纹理）、OGG/WAV（音效）、TTF/OTF（字体）、MDL（3D 模型）
4. **3D 模型格式**：Kenney 的 GLB 格式不能直接用于 UrhoX（需 MDL），推荐使用引擎内置模型或 `search_3d_resource` 工具
5. **代理必须**：沙盒环境所有网络请求必须走 `http://127.0.0.1:1080` 代理

---

*最后更新: 2026-03-28*
*基于实际测试验证*
