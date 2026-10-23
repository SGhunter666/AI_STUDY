class_name UiFont
extends RefCounted
## Godot 内置字体不含中文字形，这里从系统里挑一个可用中文字体作为全局 UI 字体。
## 只替换字体，不动字号/颜色，所以不会影响各处逐项设置的样式。
## 主菜单与对战场景都调用它，保证两处字体一致。

const CANDIDATES := [
	"PingFang SC", "Hiragino Sans GB", "Heiti SC", "STHeiti",
	"Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "Arial Unicode MS",
]


static func apply(host: Node) -> void:
	var win := host.get_window()
	if win == null:
		return
	var f := SystemFont.new()
	f.font_names = PackedStringArray(CANDIDATES)
	f.allow_system_fallback = true
	var theme := Theme.new()
	theme.default_font = f
	theme.default_font_size = 13
	win.theme = theme
