## FLYING RUINS SYSTEM - SETUP GUIDE
##
## This system generates floating ruins with teleport stones that connect them.
## When a player stands on a teleport stone, they can teleport to the next ruin.
##
## SETUP INSTRUCTIONS:
##
## 1. Create the RuinManager node:
##    - In your main scene, add a Node called "RuinManager"
##    - Attach the ruin_manager.gd script to it
##    - In _ready(), call: initialize(5)  # Creates 5 ruins
##
## 2. Integrate with the world generator:
##    - In your main world generation script, get the RuinManager
##    - For each ruin from the manager, add it to your voxel terrain
##
## 3. Add teleport system to player:
##    - Create a new Node called "TeleportSystem" as a child of the player
##    - Attach teleport_system.gd to it
##    - It will auto-find the RuinManager and player
##
## 4. Handle player input for teleportation:
##    - In your player input script, listen for teleport input (e.g., E key)
##    - Call: $TeleportSystem.teleport_to_next_ruin()
##
## 5. Display teleport UI:
##    - In your HUD, check: $TeleportSystem.get_teleport_info()
##    - Show "Press E to teleport" when on_stone is true
##    - Show cooldown timer using cooldown_remaining
##
## CUSTOMIZATION:
##
## RuinManager properties to adjust:
##   - num_ruins: Number of ruins to generate
##   - horizontal_spacing: Distance between ruins (X/Z spread)
##   - vertical_spacing: Height difference between ruins
##   - base_altitude: Starting altitude for first ruin
##
## RuinGenerator parameters (per ruin):
##   - size: Ruin room dimensions (8x8x8 to 25x25x25)
##   - ruin_index: Which ruin this is
##   - total_ruins: Total ruin count
##
## TeleportSystem customization:
##   - teleport_cooldown: Seconds between teleports
##   - Modify _check_teleport_stone_contact() for different detection
##
## FILES:
##   - ruin_generator.gd: Generates individual ruin structures
##   - ruin_manager.gd: Manages all ruins and teleportation logic
##   - teleport_system.gd: Handles player input and position updates
##
## EXAMPLE USAGE:
##
## In your main game script:
## ```gdscript
## func _ready():
##     var ruin_mgr = RuinManager.new()
##     add_child(ruin_mgr)
##     ruin_mgr.initialize(5)  # Generate 5 ruins
##     
##     # Add ruins to voxel terrain
##     for i in range(ruin_mgr.num_ruins):
##         var ruin = ruin_mgr.get_ruin(i)
##         var pos = ruin_mgr.get_ruin_position(i)
##         _add_ruin_to_terrain(ruin, pos)
## ```
##
## In your player input script:
## ```gdscript
## func _input(event: InputEvent):
##     if event.is_action_pressed("ui_accept"):  # Or custom key binding
##         if has_node("TeleportSystem"):
##             $TeleportSystem.teleport_to_next_ruin()
## ```
