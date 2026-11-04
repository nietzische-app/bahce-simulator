# Studio FBX models (art pass 1)

Import these into Roblox Studio → **ReplicatedStorage/Models/<stem>**.

| File | Role |
|------|------|
| SunBloom_seedling.fbx / SunBloom_mature.fbx | Tohum büyüme |
| DewLeaf_seedling.fbx / DewLeaf_mature.fbx | Tohum büyüme |
| CloudBerry_seedling.fbx / CloudBerry_mature.fbx | Tohum büyüme |
| MoonPetal_seedling.fbx / MoonPetal_mature.fbx | Tohum büyüme |
| StarRoot_seedling.fbx / StarRoot_mature.fbx | Tohum büyüme |
| GardenPlot.fbx | Bahçe toprak yatağı |
| SeedShopStall.fbx | Tohum dükkanı |
| SellStand.fbx | Satış tezgâhı |

Kaynak: AI referans (`assets/refs`) → free TRELLIS image→3D (`assets/models/raw/*.glb`) → Blender cleanup (`art/blender/cleanup_export.py`) → FBX (<5k tri).
Önizleme: `shots/art_contact_sheet.png`.

## Dekor modelleri (AI art bekliyor)
`ReplicatedStorage/Models/<ad>` altına import edin; yoksa yer tutucu Part görünür (bkz. `src/shared/Config/Decor.luau`):
Decor_Fence, Decor_Bench, Decor_Lantern, Decor_Fountain, Decor_FlowerPot, Decor_Birdhouse, Decor_Gnome, Decor_Swing.
Pivot = taban merkezi, ~4x4 stud yuvaya sığmalı.
