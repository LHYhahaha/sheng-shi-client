# 底部导航图片资源规范

底部导航图标使用独立图片资源目录：

```text
assets/navigation/bottom_tab/
  home_selected.png
  home_unselected.png
  for_you_selected.png
  for_you_unselected.png
  my_list_selected.png
  my_list_unselected.png
  profile_selected.png
  profile_unselected.png
```

从 Figma 导出时，分别导出选中态和未选中态图标，并按以上文件名覆盖即可。Dart 代码已经指向这些路径，不需要再改代码。

建议：

- 使用透明背景 PNG。
- 导出尺寸优先使用设计稿原始 icon 尺寸，并额外导出 `2x` 或 `3x` 时保持文件名最终一致。
- 选中态和未选中态颜色由图片自身承载，不再依赖 Flutter 的 `Icon` 着色。
- 在图片资源未补齐前，代码会临时回退到 Material icon，避免页面加载失败。
