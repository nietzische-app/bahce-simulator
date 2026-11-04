# Studio'ya FBX import (Minik bahçe)

Rojo **FBX enjekte edemez**. Modelleri Roblox Studio'da 3D Importer ile `ReplicatedStorage.Models` altına koymanız gerekir.

## Adımlar

1. Roblox Studio'da oyunu açın (Rojo sync açık olabilir).
2. **Avatar → 3D Importer** (veya dosyayı sürükle-bırak).
3. `assets/models/<Ad>.fbx` seçin (ör. `Decor_Bench.fbx`).
4. Import ayarları (önerilen):
   - Scale: Studio otomatik; model ~1.5–3 stud yüksekliğinde olmalı.
   - Pivot: taban merkezi (dosyalar cleanup ile tabana oturtuldu).
5. Import sonrası çıkan Model'i **yeniden adlandırın** — isim **birebir** şu listeden biri olmalı:
   - Pet: `Pet_Bunny`, `Pet_Chick`, `Pet_Frog`, `Pet_Fox`, `Pet_Owl`, `Pet_Hedgehog`, `Pet_Dragon`
   - Dekor: `Decor_Fence`, `Decor_Bench`, `Decor_Lantern`, `Decor_Fountain`, `Decor_FlowerPot`, `Decor_Birdhouse`, `Decor_Gnome`, `Decor_Swing`
   - Ekipman: `Sprinkler`
6. Model'i `ReplicatedStorage` → `Models` klasörüne taşıyın (yoksa oluşturun).
7. Oyun içi yer tutucu Part'lar bu isimlerle değiştirilir (`src/shared/Config`).

## .rbxm alternatifi

FBX Rojo ile gelmez. İsterseniz Studio'da import ettikten sonra Model'i sağ tık → **Save to File** ile `.rbxm` / `.rbxmx` kaydedip ekibinize paylaşabilirsiniz; yine de Rojo tree'ye binary mesh gömmek yerine Studio import standardı tercih edilir.

## Tekrar üretmek

```bash
export HF_TOKEN=hf_xxx   # ZeroGPU kotası için önerilir
./scripts/art/gen_and_convert.sh --from-manifest scripts/art/assets_manifest.json --skip-image-gen
# veya tek model:
./scripts/art/gen_and_convert.sh --name Pet_Bunny
```

Poly Haven CC0 ham dosyalar: `assets/models/raw/_poly_*`.
