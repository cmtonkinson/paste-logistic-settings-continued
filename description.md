# Credits
A huge thanks to Ezza for the original Paste Logistic Settings mod. This is a spiritual successor to that excellent utility.

# Overview
This mod makes setting up bot malls easier. You can already shift+copy/paste from assemblers to requester chests, but this mod allows you to configure inserters and storage chests as well, saving a ton of time and clicking.

# Features
Copy a recipe from any crafting machine (assembler, chemical plant, furnace, etc.) with `control + shift + right click`. Then, you can paste using `control + shift + left click` onto:

![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/assembler.png?ref_type=heads)

#### Inserters
Pasting to an inserter will:
1. Enable the logistics network connection
2. Set the inserter to "enabled" when the network contains less than one stack of the item

Before:  
![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/inserter-before.png?ref_type=heads)

After:  
![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/inserter-after.png?ref_type=heads)

You can override the stack behavior with the "Output limit" mod setting. By default this is set to "0" (which is a special value meaning "one stack") but setting it to any positive integer will cause the inserter limit to be set to that specific value (not stacks). A common use case would be to set this to "1" if you didn't want to be buffering full stacks of things.

#### Storage Chests
Pasting to a storage chest will:
1. Set the logistics filter of the storage chest to the item being copied

Before:  
![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/storage-chest-before.png?ref_type=heads)

After:  
![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/storage-chest-after.png?ref_type=heads)

#### Requester (and Buffer) Chests
Pasting to a requester chest will:
1. Create a new (unnamed) logistic group requesting one stack of each of ingredients for the recipe.

Before:  
![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/requester-chest-before.png?ref_type=heads)

After:  
![](https://gitlab.com/cmtonkinson/paste-logistic-settings-continued/-/raw/main/images/requester-chest-after.png?ref_type=heads)

If there is alredy an empty logistic group, it will be used instead of creating a new one. If there is an existing logistic group that contains the same types of ingredients, it will be overridden.

**Note:** In order for the mod to override an existing logistic group:
1. It must not be named - this is a protection built-in to prevent any unwanted side effects.
2. It MUST contain a filter for every ingredient.
3. It must contain filters ONLY for ingredients of the recipe.

