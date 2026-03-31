# LiquidGlassWeChat5.0

一个给微信用的 Theos tweak，在 iOS 16.5 上尽量模拟 iOS 26 的 Liquid Glass 观感。

## 功能

- 给微信顶部导航栏增加玻璃材质效果
- 给微信底部 TabBar 增加玻璃材质效果
- 适配浅色 / 深色模式
- 适合 TrollFools 注入使用

## 构建

### 本地构建
确保已经安装 Theos，然后执行：

```bash
make clean package FINALPACKAGE=1
