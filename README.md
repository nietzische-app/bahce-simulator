# Minik Bahçe (Bahçe Simülatörü)

Çocuklara uygun, orijinal temalı bir Roblox bahçe simülatörü MVP’si. Tohum ek, büyümesini bekle (çevrimdışı zaman damgası ile), hasat et, dükkândan sat / yükselt. Grow a Garden tarzı döngü; meme/şaka yok, sakin ve güvenli.

> Bu depo bir **Rojo** projesidir. FBX import **isteğe bağlıdır**: `ReplicatedStorage.Models` boşken Play, `ModelFallback` ile renkli Part / silindir / küre / kama modelleri gösterir. Aynı isimle import edilen mesh varsa o kullanılır.

## Özellikler

- DataStore kayıt/yükleme (oturum kilidi + yeniden deneme)
- Otomatik parsel atama (çalışma anında Part’lardan N parsel)
- Tohum kataloğu (nadirlik, büyüme süresi, satış fiyatı)
- Bitki → zamanlayıcı → hasat → satış → tohum/yükseltme satın alma
- Haftalık hava / etkinlik çarpanları (config)
- leaderstats + OrderedDataStore sıralaması
- Günlük giriş ödülü
- Kod ile üretilmiş ScreenGui (coin, envanter, dükkân, ProximityPrompt)
- Monetizasyon kancaları (gamepass / developer product ID’leri yer tutucu)
- Sunucu otoriteli Remote’lar, doğrulama ve hız sınırlama
- Oyuncu-oyuncu takas yok; gizli loot box yok (Tohum Paketi oranları açık)

## Klasör yapısı

```
default.project.json
src/
  shared/          # Config + Core (sim’ler arası yeniden kullanılabilir)
  server/          # Core (ProfileStore, Remotes) + Systems
  client/          # UI + Controllers
.github/workflows/ci.yml
```

## Gereksinimler

- [Rojo](https://rojo.space/) 7.x (CLI + Studio eklentisi)
- Roblox Studio
- (İsteğe bağlı) [Selene](https://kampfkarren.github.io/selene/), StyLua

## Studio’da açma (Rojo)

1. Bu repoyu klonla.
2. Terminalde proje kökünde:

```bash
rojo serve
```

3. Roblox Studio’da Rojo eklentisini aç → **Connect** (varsayılan `localhost:34872`).
4. Sync sonrası `ServerScriptService.Server`, `StarterPlayerScripts.Client`, `ReplicatedStorage.Shared` görünür.

Yerel place dosyası üretmek için:

```bash
rojo build -o BahceSimulator.rbxlx
```

`BahceSimulator.rbxlx` dosyasını Studio ile açabilirsin.

## Gamepass / ürün ID’lerini ayarlama

Dosya: `src/shared/Config/Monetization.luau`

Creator Dashboard’da oluşturduğun ID’leri yer tutucuların (`0`) yerine yaz:

| Anahtar | Tür | Açıklama |
|--------|-----|----------|
| `DoubleSell` | Game Pass | 2x satış |
| `AutoHarvest` | Game Pass | Otomatik hasat |
| `ExtraPlot` | Game Pass | Ekstra parsel |
| `InstantGrow` | Developer Product | Anında büyüt (zorunlu değil) |
| `SeedPack` | Developer Product | Tohum paketi (oranlar config’te açık) |

ID’ler `0` iken istemci “yapılandırılmadı” uyarısı gösterir; gerçek satın alma işlenmez.

## Yayınlama

1. Studio’da File → Publish to Roblox (yeni deneyim veya mevcut).
2. Game Settings → Security: **Enable Studio Access to API Services** (DataStore test için).
3. Monetization ID’lerini prod değerleriyle güncelle, tekrar sync/publish.
4. Experience’ı **Public** yapmadan önce aşağıdakileri kontrol et.

## Çocuk güvenliği (kid-safe) notları

- Tema sakin bahçe; şiddet, korku, flört, bahis yok.
- Oyuncu-oyuncu takas yok.
- Gizli rastgele loot box yok; rastgele ödül varsa oranlar UI’da yazılı.
- “Beklemeyi atla” baskısı yok: Instant Grow isteğe bağlı, büyüme ücretsiz beklenir.
- Roblox [Experience Guidelines](https://create.roblox.com/docs/production/experience-guidelines) / maturity anketini doğru doldur (yaş uygunluğu).
- ABD’de çocuklara yönelik hizmetler için [COPPA](https://www.ftc.gov/business-guidance/privacy-security/childrens-privacy) ve Roblox ebeveyn / hesap kurallarına uy.
- Chat’i gerekirse deneyim ayarlarından kısıtla; üçüncü taraf link paylaşma.


## 3D asset import (Studio)

Kaynak dosyalar: `assets/models/*.fbx` (ve isteğe bağlı `.obj`). Önizleme: `shots/art_contact_sheet.png`.

### Toplu import

1. Roblox Studio’da File → **3D Importer** (veya Avatar → 3D Importer) ile tek tek FBX seç **veya**
2. **Asset Manager** → Bulk Import ile `assets/models/` klasöründeki FBX’leri yükle.
3. Import ayarları: Scale unit = studs / meters uyumlu; texture’ları gömülü bırak.
4. Ortaya çıkan Model / MeshPart’ları **ReplicatedStorage → Models** altına taşı ve **dosya adıyla aynı** isim ver:

| Dosya | ReplicatedStorage yolu |
|-------|------------------------|
| `SunBloom_seedling.fbx` | `ReplicatedStorage/Models/SunBloom_seedling` |
| `SunBloom_mature.fbx` | `ReplicatedStorage/Models/SunBloom_mature` |
| `DewLeaf_*` / `CloudBerry_*` / `MoonPetal_*` / `StarRoot_*` | aynı kural |
| `GardenPlot.fbx` | `ReplicatedStorage/Models/GardenPlot` |
| `SeedShopStall.fbx` | `ReplicatedStorage/Models/SeedShopStall` |
| `SellStand.fbx` | `ReplicatedStorage/Models/SellStand` |

5. Oyun çalışınca `ModelCatalog` önce `ReplicatedStorage.Models/<Ad>` klonlar. Kayıt yoksa `ModelFallback` çocuk dostu bir Part modeli kurar (bitki, pet, dekor, ağaç, tezgâh). FBX olmadan da Play dolu görünür.

### Art pipeline (yeniden üret)

```bash
# 1) Referans görseller (HF ZeroGPU / Z-Image; kota yoksa --prompts-only)
python art/gen_refs.py

# 2) Image→3D: ücretsiz TRELLIS (örn. three.ws / HF Spaces), GLB’yi assets/models/raw/ altına koy

# 3) Blender temizlik + FBX (<5k tri)
blender --background --python art/blender/cleanup_export.py -- \
  --input-dir assets/models/raw --output-dir assets/models \
  --max-tris 5000 --contact-sheet shots/art_contact_sheet.png
```

`Blender` yalnızca cleanup / decimate / scale / material / export içindir; final mesh AI image→3D’den gelir.

## CI

GitHub Actions: `selene` lint + `rojo build`, `.rbxlx` artifact olarak yüklenir.

## Lisans / not

Eğitim / MVP iskeleti. Asset’ler placeholder; üretim sanatını kendin ekle.
