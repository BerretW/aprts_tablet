Zde je kompletní technická dokumentace pro vývojáře, kteří chtějí vytvářet externí pluginy (aplikace) pro **aprts_tablet**.

---

# 📚 Dokumentace pro vývojáře: Tablet Plugin API

Tento dokument slouží jako návod pro vytváření externích resources (pluginů), které přidávají nové aplikace do tabletu. Systém je navržen tak, aby umožňoval vkládat HTML/CSS/JS aplikace přímo do prostředí tabletu.

## 📋 1. Základní nastavení (fxmanifest.lua)

Váš resource musí mít závislost na `aprts_tablet`, aby se načetl ve správném pořadí.

```lua
fx_version 'cerulean'
games {'gta5'}

name 'moje_tablet_aplikace'
description 'Skvělá aplikace pro tablet'

-- Důležité: Závislost na jádru tabletu
dependencies {
    'aprts_tablet'
}

-- Načtení souborů pro UI (HTML, CSS, JS, Obrázky)
files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/img/*.png'
}

client_scripts { 'client.lua' }
server_scripts { 'server.lua' }
```

---

## 💻 2. Registrace aplikace (Client Side)

Aby se ikonka aplikace objevila na ploše tabletu, musíte ji zaregistrovat pomocí exportu `RegisterApp`.

### Syntax

```lua
exports['aprts_tablet']:RegisterApp(appId, label, icon, color, eventName, jobRestriction, sizeMB, osSupport)
```

### Příklad registrace

```lua
local APP_ID = 'moje_appka'

CreateThread(function()
    Wait(1000) -- Počkáme, až se tablet inicializuje
    exports['aprts_tablet']:RegisterApp(
        APP_ID,              -- Unikátní ID (bez mezer)
        'Moje Appka',        -- Název pod ikonou
        'fas fa-gamepad',    -- FontAwesome ikona (v5/v6)
        '#e74c3c',           -- Barva pozadí ikony (HEX)
        APP_ID..':open',     -- Event, který se spustí po kliknutí
        nil,                 -- Joby (např. {['police']=true}) nebo nil pro všechny
        150,                 -- Velikost aplikace v MB (pro Store a Storage)
        'all'                -- Podporované OS: 'all', 'modern', 'retro', nebo tabulka {'modern', 'kali_os'}
    )
end)
```

---

## ⚙️ 3. Otevření aplikace a načtení HTML

Když uživatel klikne na ikonu, tablet spustí event definovaný při registraci. Vaším úkolem je načíst HTML obsah a poslat ho do tabletu.

### Event `APP_ID:open`

Tablet pošle dva argumenty: `serial` (sériové číslo tabletu) a `osType` (typ systému, např. "modern", "retro").

```lua
RegisterNetEvent('moje_appka:open', function(serial, osType)
    -- 1. (Volitelné) Kontrola Wi-Fi
    local data = exports['aprts_tablet']:GetTabletData()
    if not data.wifi.isConnected then
        -- Můžete zobrazit error HTML nebo nic neudělat
    end

    -- 2. Načtení HTML souboru
    -- Funkce LoadResourceFile načte raw string z vašeho souboru
    local html = LoadResourceFile(GetCurrentResourceName(), 'web/index.html')

    -- 3. Nahrazení placeholderů (volitelné)
    -- Dobré pro vložení Serialu nebo jména hráče přímo do HTML před odesláním
    html = html:gsub('{{SERIAL}}', serial)

    -- 4. Odeslání obsahu do tabletu
    -- Toto vloží vaše HTML do <div id="app-content"> uvnitř tabletu
    TriggerEvent('aprts_tablet:loadContent', html)
end)
```

---

## 🎨 4. HTML a CSS (Pravidla a Omezení)

Vaše aplikace běží uvnitř již existující stránky tabletu. **To přináší specifická omezení.**

### ⛔ Co NESMÍTE dělat (CSS):

1. **Nikdy nepoužívejte `body` nebo `html` selektory.**
   * *Špatně:* `body { background: white; }` -> Přebarvíte celý tablet a rozbijete UI ostatním.
   * *Špatně:* `button { color: red; }` -> Změníte tlačítka v celém systému.
2. **Nepoužívejte `position: fixed` bez rozmyslu.**
   * Element se vztáhne k oknu prohlížeče (celé obrazovce), ne k rámečku tabletu. Používejte `position: absolute` uvnitř vašeho hlavního wrapperu.
3. **Nepoužívejte `z-index` vyšší než 1000**, pokud nechcete překrýt rámeček tabletu.

### ✅ Jak to dělat správně:

Vše obalte do unikátního wrapperu (třídy nebo ID) a styly vztahujte k němu.

**index.html:**

```html
<!-- Unikátní ID pro vaši aplikaci -->
<div id="moje-appka-wrapper">
    <div class="header">Vítejte</div>
    <button onclick="MojeApp.kliknuti()">Klikni mě</button>
</div>

<!-- Načtení vašich scriptů/stylů -->
<!-- Použijte nui://nazev_resource/cesta -->
<link rel="stylesheet" href="nui://moje_tablet_aplikace/web/style.css">
<script src="nui://moje_tablet_aplikace/web/script.js"></script>
```

**style.css:**

```css
/* Všechny styly začínají ID vašeho wrapperu */
#moje-appka-wrapper {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background-color: #2c3e50; /* Vaše pozadí aplikace */
    color: white;
}

#moje-appka-wrapper .header {
    font-size: 20px;
}
```

---

## 🔗 5. Komunikace JS <-> Lua (Action Handler)

Tablet poskytuje vestavěný bridge pro komunikaci, takže nemusíte registrovat vlastní `RegisterNUICallback`.

### Javascript (Odeslání dat)

Použijte funkci `System.pluginAction(appId, actionName, dataObject)`. Tato funkce je globálně dostupná v tabletu.

```javascript
var MojeApp = {
    kliknuti: function() {
        // Odeslání požadavku do Lua
        System.pluginAction('moje_appka', 'ulozitData', {
            text: "Ahoj světe",
            cislo: 123
        });
    }
}
```

### Lua Client (Příjem dat)

Musíte naslouchat eventu `APP_ID:handleAction`.

```lua
RegisterNetEvent('moje_appka:handleAction', function(action, data)
    if action == 'ulozitData' then
        print("Přišlo z JS:", data.text, data.cislo)
      
        -- Zde můžete volat Server Event
        TriggerServerEvent('moje_appka:server:save', data)
  
    elseif action == 'jinaAkce' then
        -- ...
    end
end)
```

### Lua Client -> Javascript (Odeslání zpět)

Pro poslání dat zpět do vašeho JS použijte `exports['aprts_tablet']:SendNui(data)`.

**Lua:**

```lua
exports['aprts_tablet']:SendNui({
    action = "moje_appka_update",
    status = "ok"
})
```

**Javascript (Listener):**

```javascript
window.addEventListener('message', function(event) {
    var data = event.data;
  
    // Filtrujte pouze akce pro vaši aplikaci
    if (data.action === 'moje_appka_update') {
        console.log("Status update:", data.status);
    }
});
```

---

## 🛠 6. API Reference (Seznam Exportů)

### Client Exports

| Export            | Parametry                                         | Popis                                                        |
| :---------------- | :------------------------------------------------ | :----------------------------------------------------------- |
| `RegisterApp`   | `id, label, icon, color, event, jobs, size, os` | Hlavní registrace aplikace.                                 |
| `GetTabletData` | *žádné*                                      | Vrací tabulku:`{ battery, wifi, serial, model, time }`.   |
| `SendNui`       | `data (table)`                                  | Pošle data do NUI (alternativa k `SendNUIMessage`).       |
| `SetAppBadge`   | `appName, count`                                | Nastaví červený odznak s číslem na ikoně (0 = smazat). |
| `SaveAppData`   | `appName, key, value`                           | Uloží jednoduchá data k aplikaci do SQL (permanentní).   |
| `loadContent`   | `htmlString`                                    | Vloží HTML do obsahu tabletu (voláno přes TriggerEvent). |

### Globální JS Funkce (v tabletu)

| Funkce                          | Parametry                       | Popis                                        |
| :------------------------------ | :------------------------------ | :------------------------------------------- |
| `System.pluginAction`         | `appId, action, data`         | Pošle data do Lua (`handleAction` event). |
| `System.playSound`            | `'click' \| 'notify' \| 'lock'` | Přehraje systémový zvuk tabletu.          |
| `System.API.showNotification` | `payload object`              | Zobrazí SweetAlert2 notifikaci.             |

**Příklad notifikace z JS:**

```javascript
System.API.showNotification({
    title: "Úspěch",
    text: "Data byla uložena.",
    icon: "success", // success, error, warning, info
    toast: true      // true = malá bublina v rohu
});
```

---

## 💡 Tipy pro vývoj

1. **Responzivita:** Tablet má fixní rozlišení kontejneru (nastaveno v CSS `1000px x 700px`), ale obsah scrolluje. Navrhujte aplikaci tak, aby se vešla do tohoto rámu.
2. **Témata:** Pokud chcete podporovat "Retro" i "Modern" vzhled, můžete v JS zkontrolovat třídu na body (ale spolehlivější je si poslat `osType` z Lua) a podle toho načíst jiné CSS nebo změnit styly.
3. **App Store:** Nezapomeňte nastavit reálnou velikost `size` v MB při registraci. Pokud hráč nemá místo na disku tabletu, aplikaci si nebude moci nainstalovat.
