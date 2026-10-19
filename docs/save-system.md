# 存档系统 —— 使用与对接说明

> 面向：做主菜单 UI、以及要摆放存档点的策划/程序。
> 核心：角色踩到「存档点」后，死亡会复活在存档点；主菜单「继续游戏」回到最近存档的位置；「开始游戏」清空进度重开。

## 一句话

- 存档点 = 预制体 `prefabs/rooms/checkpoint.tscn`，拖进关卡即可。
- 存档文件 = `user://save.json`，由 `GameState` 自动读写。
- 主菜单对接 = 「开始游戏」调 `GameState.new_game()`，「继续游戏」调 `GameState.continue_game()` + `SceneManager.resume_from_checkpoint()`。

## 1. 存档点怎么摆

把 `prefabs/rooms/checkpoint.tscn` 拖进场景，放在想让角色复活的位置即可。

- 触发范围：256×256 的矩形（`Collision` 子节点的 Shape Size，想调大改它）。
- 角色走进触发区即记录存档点，并自动写盘、左上角提示「已记录存档点」。
- 占位色块只在编辑器里可见，游戏运行时自动隐藏，玩家看不到。
- 一个关卡可以放多个存档点，角色经过哪个，哪个就是最新的复活点。

### 已摆放的存档点

各关卡目前已放好的存档点（场景内坐标）：

| 关卡 | 节点名 | 位置 |
| --- | --- | --- |
| `level_1.tscn` | `Checkpoint` | `(-9279, -7906)` |
| `level_2.tscn` | `Checkpoint` | `(-5202, -19165)` |
| `level_2.tscn` | `Checkpoint2` | `(9036, -19165)` |
| `level_3.tscn` | `Checkpoint` | `(12942, 3129)` |
| `level_4.tscn` | `Checkpoint` | `(0, 0)`（spawn 出生点） |

要新增或挪动存档点，直接改对应场景里的 `Checkpoint` 节点位置即可。

## 2. 死亡复活规则

- 如果最近一次存档点就在**当前场景**：死亡后复活到存档点坐标。
- 如果存档点在其他场景、或没有存档点：死亡后回到当前场景的 `spawn` 出生点。

这条规则已经写在 `player.gd` 的 `_spawn_position()` 里，不需要主菜单侧处理。

## 3. GameState 存档 API

所有方法都是 `GameState` 上的公开方法，直接调用即可。

| 方法 | 作用 | 返回值 |
| --- | --- | --- |
| `has_checkpoint()` | 当前内存里是否有存档点 | `bool` |
| `has_save_file()` | 磁盘上是否存在存档文件 | `bool` |
| `save_game()` | 把当前进度 + 存档点写盘 | 无 |
| `load_game()` | 从磁盘读回进度 + 存档点 | 成功 `bool` |
| `continue_game()` | 等价于 `load_game()`，读档 | 成功 `bool` |
| `new_game()` | 清空全部进度、清掉存档点、删除存档文件 | 无 |
| `set_checkpoint(scene, pos)` | 记录存档点并写盘（checkpoint 节点内部用） | 无 |

字段：

- `checkpoint_scene: String` —— 存档点所在场景路径，如 `res://scenes/level_2.tscn`。
- `checkpoint_pos: Vector2` —— 存档点世界坐标。

存档文件内容：存档点（场景 + 坐标）+ 当前进度（钥匙、道具、能力、开关、已解锁的门、元素库存等）+ 有限种子容器的剩余库存与冻结状态。存档时先抓取当前房间，避免继续游戏后容器重新补满而背包仍保留已取种子。旧存档缺少容器字段时保持兼容，但无法还原旧版本未记录的容器余量。其他机关的内部状态（房间里解到一半的谜题）暂未纳入磁盘存档，后续需要再扩展。

## 4. SceneManager 对接

| 方法 | 作用 |
| --- | --- |
| `change_room(scene, entrance)` | 正常切场景，把玩家定位到 `entrance` 入口 |
| `resume_from_checkpoint()` | 继续游戏：切到存档点场景，并把玩家定位到存档点坐标；没有存档返回 `false` |

注意 `change_room` / `resume_from_checkpoint` 是异步的（内部 `call_deferred`），调用后场景会在下一帧才真正切换，不要在同一条语句后面立刻读新场景状态。

## 5. 主菜单 UI 对接

### 已接入的主菜单行为

- 启动时 `GameContainer._enter_tree()` 读取并校验存档，先于玩家及房间初始化。
- 有有效存档：菜单背景加载最近存档点所在关卡，玩家放在该存档点附近，继续沿用纸面起稿效果；「继续游戏」可用并默认获得焦点。
- 无存档、JSON 损坏、坐标格式错误、关卡已删除：背景回退起始关卡，「继续游戏」置灰。预览不删除或覆盖磁盘存档。
- 背景随**最近一次已保存的存档点**变化，不跟随尚未保存的探索位置。同一关卡的不同存档点也会改变背景构图。
- 「继续游戏」再次读取磁盘存档，重新创建玩家、房间及 HUD，然后播放原有镜头和纸面揭幕过渡。
- 有存档时点「开始游戏」会显示菜单内的确认区；确认才调用 `new_game()` 清空重开，返回不会清档。
- 玩家初始化同时恢复元素库存与生命升级，避免只恢复 `GameState`、玩家仍是空背包的情况。
- 跟班完成首次对话后记录 `companion_recruited`，随存档点写盘；继续游戏会在玩家旁恢复跟班，无需重播招募对话。后续关卡使用 `prefabs/creatures/companion.tscn` 补建，第一关复用原有角色，避免重复。新游戏清除此状态。
- 旧存档无招募字段时，以后续关卡或已有元素库存兼容推断已招募；明确保存的 `false` 不会被推断覆盖。旧版第一关且无元素的存档没有足够信息判断是否已招募。
- `GameState.has_valid_save()` 可只检查存档是否可继续，不修改当前进度。

实现中菜单用 `GameState.menu_launch_action` 传递一次性启动意图（`new` / `continue`），先以纸面遮住背景，再重载 `game.tscn`。重建后消费该字段，在玩家 `_ready()` 前完成清档或读档；房间就绪后才揭幕。`SceneManager.setup()` 同时清理已释放房间对应的旧切换守卫，避免菜单暂停时遗留冷却导致切房请求丢失。

下面是 API 的简化调用示例；实际菜单通过上述重建流程执行，不直接在旧玩家上清档切房。

### 开始游戏（重新开始）

```gdscript
func _on_new_game_pressed() -> void:
    GameState.new_game()                      # 清进度 + 清存档点 + 删存档文件
    SceneManager.change_room(_game.start_room, _game.start_entrance)
    _hide_menu_and_start()
```

`_game.start_room`（默认 `res://scenes/level_1.tscn`）和 `_game.start_entrance`（默认 `"spawn"`）在 `game_container.gd` 上，可直接读。

### 继续游戏（回到最近存档）

```gdscript
func _on_continue_pressed() -> void:
    if GameState.continue_game():              # 读档，返回是否有存档
        if SceneManager.resume_from_checkpoint():
            _hide_menu_and_start()
    else:
        _show_no_save_hint()                    # 提示「没有存档」或把按钮置灰
```

按钮状态建议：菜单出现时用 `GameState.has_save_file()` 决定「继续游戏」是否可点/显示；没有存档就置灰或隐藏。

### 菜单揭幕时机

现有 `main_menu.gd` 是等 `SceneManager.room_changed` 后暂停、揭幕。对接存档后建议保持这个顺序：先完成切场景（无论新游戏还是继续游戏），菜单再揭幕，避免玩家在切换间隙操作。

## 6. 存档文件位置

`user://save.json`。Windows 下实际路径通常是：

```
C:/Users/<用户名>/AppData/Roaming/Godot/app_userdata/Color/save.json
```

删除这个文件 = 清空存档，等价于 `GameState.new_game()`。

## 7. 注意事项

- 「开始游戏」一定要先 `new_game()` 再切场景，否则会带着上一局的钥匙/开门状态进入第一关。
- `resume_from_checkpoint()` 只有在 `GameState.continue_game()` 返回 `true`（确实读到了存档）之后调用，否则会切到空场景。
- 存档点记录的是「场景路径 + 坐标」，如果关卡大改把存档点挪了位置，旧存档里的坐标可能落在墙里；调试期可以手动删 `save.json` 或让存档点重新触发。
