# Credits
A huge thanks to Ezza for the original Paste Logistic Settings mod. This is a spiritual successor to that excellent utility.

# Overview
This mod makes setting up bot malls easier. You can already copy/paste from assemblers to requester chests, but this mod allows you to quickly configure inserters and storage chests as well, saving a ton of time and tedious clicking.

# Features
Copy a recipe from any crafting machine (assembler, chemical plant, furnace, etc.) using `control + shift + right click`  and paste using `control + shift + left click`. Since the mod uses the same modifier keys as super force build, to prevent any unintended interactions it will not activate if there is anything held in the cursor (items, ghosts, blueprints, upgrade planners, etc).

![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/assembler.png?ref_type=heads)

#### Inserters
Pasting to an inserter will:
1. Enable the logistics network connection
2. Set the inserter to "enabled" when the network contains less than one stack of the item

By default, pasting the same recipe into the same inserter again will add the
new output limit to the existing one. This can be disabled in the runtime mod
settings.

![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/outserter.png?ref_type=heads)

#### Storage Chests
Pasting to a storage chest will:
1. Set the logistics filter of the storage chest to the item being copied

![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/storage-chest.png?ref_type=heads)

#### Requester (and Buffer) Chests
Pasting to a requester chest will:
1. Create a new (unnamed) logistic group requesting one stack of each of ingredients for the recipe.

![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/requester-chest.png?ref_type=heads)

If there is alredy an empty logistic group, it will be used instead of creating a new one. If there is an existing logistic group that contains the same types of ingredients, it will be overridden.

# Configuration:
The amount of ingredients requested, and outputs allowed, are all runtime user settings.

**Note:** In order for the mod to override an existing logistic group:
1. It must not be named (this is a protection built-in to prevent any unwanted side effects).
2. It must contain a filter for every ingredient of the recipe.
3. It must contain filters only for ingredients of the recipe.

#### Automatic configuration
Pasting back onto the crafting machine (or any crafting machine of the same type) will find all inserter/chest pairs associated with the machine.
1. For a requester chest feeding the machine via inserter, the chests requests will be configured.
2. For a storage chest being fed from the machine via inserter, both inserter and chest will be configured.

# Known Issues
You can submit any feedback here in a discussion thread, but you can also track and submit issues on [GitLab](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/issues).
