# Hand detector item

Needed when `Config.HandDetector.requireItem` or `usableItem` is on. The name must match `Config.HandDetector.item` (default `hand_detector`).

## ox_inventory — `ox_inventory/data/items.lua`

```lua
['hand_detector'] = {
    label = 'Hand Detector',
    weight = 400,
    stack = false,
    close = true,
    description = 'A handheld metal detector for searching people.',
},
```

## qb-core / qbx (without ox_inventory) — `qb-core/shared/items.lua`

```lua
hand_detector = { name = 'hand_detector', label = 'Hand Detector', weight = 400, type = 'item', image = 'hand_detector.png', unique = true, useable = true, shouldClose = true, description = 'A handheld metal detector for searching people.' },
```

## ESX

```sql
INSERT INTO `items` (`name`, `label`, `weight`) VALUES ('hand_detector', 'Hand Detector', 1);
```

Add an image named `hand_detector.png` to your inventory's image folder if you want one.
