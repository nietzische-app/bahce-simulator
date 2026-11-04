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

## Dekor / pet / sprinkler (art pass 2)

| File | Tris (hedef <5k) | Kaynak |
|------|------------------|--------|
| Decor_Bench.fbx | ~630 | Poly Haven CC0 |
| Decor_FlowerPot.fbx | ~3080 | Poly Haven CC0 |
| Decor_Gnome.fbx | ~5000 | Poly Haven CC0 |
| Decor_Lantern.fbx | ~4999 | Poly Haven CC0 |
| Decor_Fence.fbx | ~4999 | Poly Haven CC0 (chainlink) |
| Sprinkler.fbx | ~5000 | Poly Haven CC0 |
| Pet_Fox.fbx | ~576 | Khronos Fox CC-BY |

Eksik (HF ZeroGPU / TRELLIS bekliyor): Pet_Bunny, Pet_Chick, Pet_Frog, Pet_Owl, Pet_Hedgehog, Pet_Dragon, Decor_Fountain, Decor_Birdhouse, Decor_Swing.

Import: `docs/STUDIO_FBX_IMPORT_TR.md`. Pipeline: `scripts/art/gen_and_convert.sh`. Önizleme: `/workspace/art_preview.png` (repo dışı kopya `shots/` altına da alınabilir).

