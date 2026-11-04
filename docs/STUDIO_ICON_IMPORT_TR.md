# Studio'ya ikon import (Minik bahçe)

PNG'ler `assets/icons/`. Open Cloud WAF 403 verdiği için **rbxassetid**'yi Studio Asset Manager ile alıp `src/shared/Config/Icons.luau` içine yapıştırın.

## Adımlar

1. Roblox Studio'da oyunu açın (Rojo sync).
2. **View → Asset Manager → Bulk Import** (veya tek tek sürükle-bırak).
3. `assets/icons/*.png` seçin → Upload.
4. Her ikona tıklayıp **ID**'yi kopyalayın.
5. `src/shared/Config/Icons.luau` içinde ilgili anahtara yalnızca sayıyı yazın:
   ```lua
   Seed_SunBloom = "1234567890",
   ```
6. Rojo sync / kaydet — `Seeds.assetId` otomatik `rbxassetid://...` olur.
7. İsteğe bağlı: `assets/icons/icon_ids.mapping.txt` dosyasını da doldurun (yedek not).

## Dosya listesi

| PNG | Icons.luau anahtarı |
|-----|---------------------|
| Seed_SunBloom.png | Seed_SunBloom |
| Seed_DewLeaf.png | Seed_DewLeaf |
| Seed_CloudBerry.png | Seed_CloudBerry |
| Seed_MoonPetal.png | Seed_MoonPetal |
| Seed_StarRoot.png | Seed_StarRoot |
| World_GardenPlot.png | World_GardenPlot |
| World_SeedShop.png | World_SeedShop |
| World_SellStand.png | World_SellStand |
| Pet_Bunny.png … Pet_Hedgehog.png | Pet_* |

Seedling_*.png isteğe bağlı (büyüme UI); henüz Config'e bağlı değil.
