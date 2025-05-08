# Mod Portal Description
A huge thanks to Ezza for the original Paste Logistic Settings mod. This is a spiritual successor to that.

---

Factorio allows you to "copy" from an assembler (chemical plant, etc. - anything with a recipe) and then "paste" a requester or buffer chest and it will add the ingredients of the assembler recipe to the logistic requests of the chest. This mod allows you to quickly configure inserters and storage chests as well.

`control + shift + right click` an assembler and then `control + shift + left click`...
1. an inserter - connects the inserter to the logistic network, and adds an "enable" condition so long as there is less than 1 stack of the target item in the network.
2. a storage chest - sets the logistic filter of the chest to the target item.
3. a requester or buffer chest - creates a new (unnamed) logistic group requesting 1 stack of each of the target items recipe ingredients.

This makes setting up a bot mall very quick and easy so that you don't buffer or overproduce too much by default without a bunch of clicking around.
