# Studio'ya FBX / OBJ import (Minik bahçe)

Rojo **FBX/OBJ enjekte edemez**. Modelleri Roblox Studio'da 3D Importer ile `ReplicatedStorage.Models` altına koymanız gerekir.

## Adımlar

1. Roblox Studio'da oyunu açın (Rojo sync açık olabilir).
2. **Avatar → 3D Importer** (veya dosyayı sürükle-bırak). OBJ de kabul edilir (`assets/models/*.obj`).
3. `assets/models/<Ad>.fbx` (veya `.obj`) seçin.
4. Import ayarları (önerilen):
   - Scale: Studio otomatik; model hedef yüksekliğe yakın olmalı.
   - Pivot: taban merkezi (cleanup ile tabana oturtuldu).
5. Import sonrası Model adını **birebir** aşağıdaki listeden biri yapın.
6. Model'i `ReplicatedStorage` → `Models` klasörüne taşıyın (yoksa oluşturun).
7. Oyun yer tutucu Part'ları bu isimlerle değiştirir (`WorldLayout` + Config).

## İsim listesi (bu pas)

### Bitki büyüme
`SunBloom_seedling`, `SunBloom_mature`, `DewLeaf_seedling`, `DewLeaf_mature`, `CloudBerry_seedling`, `CloudBerry_mature`, `MoonPetal_seedling`, `MoonPetal_mature`, `StarRoot_seedling`, `StarRoot_mature`

### Hub / dükkân / toprak
`GardenPlot`, `SeedShopStall`, `SellStand`, `Sprinkler`

### Dekor (hazır)
`Decor_Fence`, `Decor_Bench`, `Decor_Lantern`, `Decor_FlowerPot`, `Decor_Gnome`

### Dünya prop (haritayı doldurur)
`WorldTree`, `WorldRock`, `WorldRocks`, `WorldFlowerA`, `WorldFlowerB`, `WorldFlowerC`, `WorldFern`, `WorldLog`

### Pet (hazır)
`Pet_Fox`

### Yarına bırakılan (şimdilik import etmeyin / yoksa yer tutucu kalır)
`Pet_Bunny`, `Pet_Chick`, `Pet_Frog`, `Pet_Owl`, `Pet_Hedgehog`, `Pet_Dragon`, `Decor_Fountain`, `Decor_Birdhouse`, `Decor_Swing`

## .rbxm alternatifi

FBX Rojo ile gelmez. Studio'da import ettikten sonra Model'i sağ tık → **Save to File** ile `.rbxm` paylaşabilirsiniz.

## Tekrar üretmek

```bash
export HF_TOKEN=hf_xxx
./scripts/art/gen_and_convert.sh --from-manifest scripts/art/assets_manifest.json
# sadece ikon (refs → assets/icons):
./scripts/art/gen_and_convert.sh --icons-only
# world Poly Haven glTF → FBX/OBJ:
./scripts/art/gen_and_convert.sh --world-props
```

Poly Haven CC0 ham: `assets/models/raw/_poly_*`. Lisanslar: `assets/CREDITS.md`.
İkonlar: `docs/STUDIO_ICON_IMPORT_TR.md`.
