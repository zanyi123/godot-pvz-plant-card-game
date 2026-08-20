## 版本管理器 - 自动配置 (AutoLoad)
## 挂载到 project.godot 作为全局单例
## 所有平台读取同一版本号，确保 PC 和手机版本一致
extends Node

## ======== 在这里修改版本号 ========
const VERSION_MAJOR: int = 1
const VERSION_MINOR: int = 4
const VERSION_PATCH: int = 0
const VERSION_SUFFIX: String = ""  # 如 "beta", "rc1", "" 表示正式版
## ==================================

static func get_version_string() -> String:
	var v = "%d.%d.%d" % [VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH]
	if VERSION_SUFFIX != "":
		v += "-" + VERSION_SUFFIX
	return v

static func get_version_code() -> int:
	## Android versionCode，递增整数，每次发版必须+1
	## 格式: MMmmpp (主版本*10000 + 次版本*100 + 补丁)
	return VERSION_MAJOR * 10000 + VERSION_MINOR * 100 + VERSION_PATCH

static func get_display_text() -> String:
	return "v" + get_version_string()

func _ready() -> void:
	if OS.has_feature("debug"):
		print("[VersionManager] 当前版本: %s (code: %d)" % [get_version_string(), get_version_code()])
