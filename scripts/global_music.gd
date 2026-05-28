## global_music.gd — 全局音乐管理器自动加载
## 在 project.godot 中注册为 AutoLoad，确保音乐跨场景不中断
##
## 用法：
##   GlobalMusic.scan()                    # 扫描世界音乐
##   GlobalMusic.play_menu()               # 主菜单BGM
##   GlobalMusic.play_pre("Ancient Egypt") # 阵前曲
##   GlobalMusic.play_game("Ancient Egypt")# 游戏BGM
##   GlobalMusic.play_card_sfx()           # 出牌音效
extends MusicManager

func _ready() -> void:
	super._ready()
	# 启动时扫描音乐
	scan()
