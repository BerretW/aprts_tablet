Dobře, tady je komplexní `README.md` pro vývojáře her v Godotu, kteří chtějí použít tvůj builder pro integraci s FiveM tabletem.

---

# Godot Game FiveM Tablet Integration (by FiveMBuilder)

Tento průvodce ti pomůže integrovat tvou Godot hru do FiveM prostředí pomocí vlastního tablet systému. Builder automatizuje většinu nastavení NUI a komunikace, takže se můžeš soustředit na vývoj hry.

---

## Obsah

1. [Úvod](#1-úvod)
2. [Předpoklady](#2-předpoklady)
3. [Nastavení Godot Builderu](#3-nastavení-godot-builderu)
4. [Integrace do Kódu Hry (Godot)](#4-integrace-do-kódu-hry-godot)
   * [A. Nastavení Autoload `FiveM.gd`](#a-nastavení-autoload-fivemgd)
   * [B. Registrace Proměnných](#b-registrace-proměnných)
   * [C. Ukládání Hry (`save_game()`)](#c-ukládání-hry-save_game)
   * [D. Odesílání Vlastních Akcí (`send_action()`)](#d-odesílání-vlastních-akcí-send_action)
   * [E. Zavření Aplikace (`close_app()`)](#e-zavření-aplikace-close_app)
5. [Export Hry z Godotu](#5-export-hry-z-godotu)
6. [Generování FiveM Resource](#6-generování-fivem-resource)
7. [Nasazení na FiveM Server](#7-nasazení-na-fivem-server)
   * [A. Struktura Resourcu](#a-struktura-resourcu)
   * [B. Úprava `client.lua` (Nejdůležitější!)](#b-úprava-clientlua-nejdůležitější)
   * [C. Server.cfg](#c-servercfg)
8. [Řešení Problémů / Důležité poznámky](#8-řešení-problémů--důležité-poznámky)

---

## 1. Úvod

Tento systém ti umožní vyexportovat Godot hru do HTML5 a automaticky ji zabalit do FiveM resourcu kompatibilního s tabletovým systémem `aprts_tablet`. Builder se postará o veškerou NUI komunikaci (`iframe`, `postMessage`, `System.pluginAction`), zatímco tvá hra v Godotu bude interagovat s jednoduchým globálním skriptem `FiveM.gd`.

## 2. Předpoklady

* **Godot Engine 3.5 LTS:** Builder je testován a vyvinut pro Godot 3.5.x.
* **Alespoň jeden funkční Godot projekt:** Tvá hra, kterou chceš exportovat.
* **FiveM Server:** S nainstalovaným a funkčním `aprts_tablet` a `ox_lib`.
* **Základní znalost LUA a JavaScriptu:** Pro úpravu `client.lua` na serveru.

## 3. Nastavení Godot Builderu

1. **Vytvoř složky:**
   * V panelu `FileSystem` Godotu (vlevo dole) klikni pravým tlačítkem na `res://`.
   * Vytvoř složku `addons`.
   * Uvnitř `addons` vytvoř složku `fivem_builder`.
2. **Vytvoř skript `FiveMBuilder.gd`:**
   * V `res://addons/fivem_builder/` klikni pravým tlačítkem -> `New Script`.
   * Pojmenuj ho `FiveMBuilder.gd` a vlož do něj **celý kód builderu**, který ti byl poskytnut.
3. **Povol Addon:**
   * Jdi do `Project -> Project Settings -> Plugins`.
   * Najdi "FiveMBuilder" a ujisti se, že je **Enabled**.
4. **Vytvoř scénu s Builderem:**
   * Vytvoř novou scénu (`Scene -> New Scene`).
   * Přidej kořenový uzel typu `Node`. Přejmenuj ho na `FiveMResourceBuilder`.
   * Na tento uzel přetáhni (attach) skript `res://addons/fivem_builder/FiveMBuilder.gd`.
   * Ulož tuto scénu (např. `res://builder_scene.tscn`).

## 4. Integrace do Kódu Hry (Godot)

Vytvoříme si globální skript, který bude fungovat jako "překladatel" mezi Godotem a FiveM.

### A. Nastavení Autoload `FiveM.gd`

1. **Vytvoř skript:**
   * Vytvoř nový skript, např. `res://scripts/FiveM.gd`.
   * Vlož do něj kód, který byl poskytnut (verze s `close_app()` a `send_action()`).
2. **Nastav Autoload:**
   * Jdi do `Project -> Project Settings -> AutoLoad`.
   * Klikni na ikonu složky, vyber `res://scripts/FiveM.gd`.
   * Do pole `Node Name` napiš: **`FiveM`**.
   * Klikni `Add`.

Nyní je objekt `FiveM` dostupný z jakéhokoliv skriptu ve tvé hře.

### B. Registrace Proměnných

Ve svém hlavním herním skriptu (`Game.gd`, `Main.gd` nebo třeba `Global.gd` – pokud máš vlastní globální data) musíš Godotu říct, které proměnné má sledovat a ukládat.

**Příklad v `Game.gd` (nebo jiném skriptu, kde jsou tvá data):**

```gdscript
extends Control # nebo Node2D, Node atd.

# Tvé herní proměnné
var player_score = 0
var current_level = 1
var player_name = "Player 1"
var inventory = ["sword", "shield"]

func _ready():
    # Zde provádíš veškerou běžnou inicializaci hry

    # --- Registrace proměnných pro FiveM ---
    # format: FiveM.register_variable("název_v_databázi", objekt_s_proměnnou, "název_proměnné")
    FiveM.register_variable("score", self, "player_score")
    FiveM.register_variable("level", self, "current_level")
    FiveM.register_variable("name", self, "player_name")
    FiveM.register_variable("inv", self, "inventory")

    # Můžeš se připojit na signál, když se data načtou z FiveM
    FiveM.connect("data_loaded", self, "_on_fivem_data_loaded")

func _on_fivem_data_loaded():
    # Tato funkce se zavolá, jakmile se data načtou z FiveM a aplikují do proměnných.
    # Zde aktualizuj své UI, pozici hráče atd.
    print("[Game] Data načtena z FiveM. Skóre: ", player_score, ", Level: ", current_level)
    # Příklad aktualizace UI:
    # $ScoreLabel.text = "Skóre: " + str(player_score)
    # $LevelLabel.text = "Úroveň: " + str(current_level)

# Důležité: proměnné v register_variable MUSÍ být exportované nebo mít set/get metody
# jinak Godot nemusí povolit přímý přístup.
# Doporučuji: var moje_promenna = 0 setget ,get_moje_promenna

```

### C. Ukládání Hry (`save_game()`)

Kdykoliv chceš uložit aktuální stav registrovaných proměnných do FiveM, stačí zavolat:

```gdscript
func _on_SaveButton_pressed():
    FiveM.save_game()
    # Můžeš přidat nějakou zpětnou vazbu, např. UI notifikaci
    # $NotificationLabel.text = "Hra uložena!"
```

### D. Odesílání Vlastních Akcí (`send_action()`)

Pokud potřebuješ poslat do FiveM konkrétní událost (např. nákup předmětu, aktivace schopnosti), aniž bys ukládal celou hru:

```gdscript
func _on_BuyButton_pressed():
    var item_id = "legendary_sword"
    var item_price = 1500
  
    # Pošle do FiveM událost "buy_item" s daty
    FiveM.send_action("buy_item", {"item": item_id, "cost": item_price})
  
    # Můžeš čekat na odpověď (pokud ji FiveM pošle přes custom event)
    # FiveM.connect("action_received", self, "_on_fivem_action")

# func _on_fivem_action(action_name, payload):
#     if action_name == "item_bought_confirm":
#         print("Potvrzení nákupu: ", payload.item)
```

### E. Zavření Aplikace (`close_app()`)

Pro vytvoření tlačítka "Zavřít aplikaci" přímo ve hře:

```gdscript
func _on_ExitAppButton_pressed():
    FiveM.close_app()
```

## 5. Export Hry z Godotu

Tento krok provedeš jen jednou, abys připravil výchozí soubory pro builder. Pokaždé, když změníš hru, stačí tento krok zopakovat a pak generovat resource.

1. Otevři svůj Godot projekt.
2. Jdi do `Project -> Export...`.
3. Přidej preset `HTML5` (pokud ho nemáš, budeš muset nainstalovat exportní šablony).
4. **Nastavení exportu:**
   * V poli `Export Path` (úplně dole) klikni na ikonu složky.
   * Vytvoř složku v rámci tvého projektu, např. `res://export_temp/`.
   * Název souboru `index.html`.
   * **DŮLEŽITÉ:** V `Options` vpravo dole nastav **`Export Type` na `GLES2`** (důležité pro kompatibilitu s FiveM CEF).
   * **ODŠKRTNI** `Export With Debug` pro menší soubory.
5. Klikni na **`Export Project`**.

## 6. Generování FiveM Resource

Nyní použijeme náš Godot Builder k vytvoření kompletního FiveM resourcu.

1. Otevři scénu `res://builder_scene.tscn` (nebo jak jsi ji pojmenoval).
2. Klikni na uzel `FiveMResourceBuilder` v panelu `Scene`.
3. V panelu **Inspector** (vpravo) uvidíš nastavení builderu:
   * **App Label:** Název aplikace v tabletu (např. "Můj Krypto Miner").
   * **App Id:** Unikátní ID aplikace (např. "crypto_miner"). Musí být unikátní v rámci tabletu!
   * **Fa Icon:** Ikona z FontAwesome (např. `fas fa-dollar-sign`).
   * **App Color:** Barva ikony (např. `#f1c40f`).
   * **Resource Name:** Název složky resourcu na FiveM serveru (např. `aprts_tablet_cryptominer`).
   * **Export Source Path:** Ujisti se, že je nastaveno na `res://export_temp` (nebo kam jsi exportoval hru).
   * **Output Folder:** Nastav, kam se má vygenerovat resource (např. `res://build` nebo přímo cesta k tvému FiveM serveru).
4. Úplně dole v Inspektoru zaškrtni políčko **`Generate Resource`**.
5. Sleduj Godot konzoli dole. Po dokončení se políčko odškrtne.

## 7. Nasazení na FiveM Server

### A. Struktura Resourcu

Vygenerovaná složka bude vypadat takto:

```
aprts_tablet_cryptominer/  <-- Toto je tvůj Resource Name
├── fxmanifest.lua
├── client.lua             <-- Zde provedeš úpravy pro FiveM logiku
└── web/
    ├── wrapper.html       <-- Obal pro hru
    ├── wrapper.js         <-- JS Bridge
    └── game/              <-- Tady jsou tvé Godot soubory (index.html, .pck, .wasm...)
        ├── index.html
        ├── index.js
        ├── index.pck
        └── ...
```

### B. Úprava `client.lua` (Nejdůležitější!)

Vygenerovaný `client.lua` je `TODO` (To Do) pro tebe. Musíš ho upravit, aby pracoval s tvými daty.

1. Otevři soubor `aprts_tablet_cryptominer/client.lua`.
2. **Sekce `RegisterNetEvent(APP_ID..':open', ...)` (Načítání dat):**
   * Nahraď řádek `local myGameData = "{}"` kódem, který načte data z tvé databáze nebo jiného zdroje.
   * **Příklad (oxmysql s JSON):**
     ```lua
     -- [TODO]: Zde načti data pro hráče
     -- Příklad: local dataFromDb = exports.oxmysql:singleSync('SELECT game_data FROM my_table WHERE serial = ?', {serial})
     -- local myGameData = dataFromDb and dataFromDb.game_data or "{}" -- Pokud nejsou data, posíláme prázdný JSON

     -- Default (dokud si nenapíšeš své):
     local myGameData = "{}"

     -- Důležité: data musí být JSON string, pokud chceš Godotu poslat objekt.
     ```
3. **Sekce `RegisterNetEvent(APP_ID..':handleAction', ...)` (Ukládání & Akce):**
   * **`action == 'saveGame'` (Ukládání hry):**
     * Zde zavolej svůj `TriggerServerEvent` nebo jinou logiku pro uložení `data.gameData` do databáze.
     * `data.gameData` je JSON objekt s všemi proměnnými, které jsi registroval v Godotu.
     * `data.serial` je sériové číslo tabletu/hráče.
   * **`action == 'closeApp'` (Zavření aplikace):**
     * Zde vlož kód, který skutečně zavře tablet. Bude záležet na implementaci tvého `aprts_tablet`.
     * **Možné řešení (zkus):**
       * `exports['aprts_tablet']:closeTablet()` (pokud existuje takový export)
       * `TriggerEvent('aprts_tablet:forceClose')` (pokud používáš takový event)
       * `SetNuiFocus(false, false)` (poslední možnost, ale nemusí se správně resetovat UI tabletu)
   * **`action == 'customAction'` (Vlastní akce):**
     * Zde zpracuj akce, které jsi poslal z Godotu pomocí `FiveM.send_action()`.
     * `data.actionName` bude jméno akce (např. "buy_item").
     * `data.payload` bude objekt s daty (např. `{item: "apple", cost: 50}`).

### C. Server.cfg

1. Zkopíruj složku `aprts_tablet_cryptominer` (nebo jak jsi ji nazval) do `resources/` na tvém FiveM serveru.
2. Do `server.cfg` přidej:
   ```
   ensure aprts_tablet_cryptominer
   ```
3. Restartuj server nebo použij `refresh` a `ensure aprts_tablet_cryptominer` v konzoli.

## 8. Řešení Problémů / Důležité poznámky

* **Godot 3.5 LTS:** Dvojitá kontrola, že používáš tuto verzi. `export_group` není podporován.
* **GLES2 Export:** Vždy exportuj Godot do HTML5 s `Export Type: GLES2`.
* **NuiFocus:** Builder automaticky přidává fix pro `NuiFocus` do tvého `index.html`, takže bys neměl mít problémy s ovládáním v Godotu.
* **JSON v LUA:** Pamatuj, že data mezi LUA a JS se předávají jako JSON stringy. Použij `json.encode()` a `json.decode()` v LUA pro práci s nimi. `ox_lib` má své vlastní JSON funkce.
* **Chybová hlášení:** Sleduj Godot Output konzoli při generování a FiveM konzoli (`F8` ve hře) při spouštění.
* **Prázdná data:** Když se hráč připojí poprvé, `client.lua` pošle prázdný JSON (`{}`). Tvůj Godot kód v `_on_fivem_data_loaded()` by s tím měl počítat a nastavit defaultní hodnoty.
* **`aprts_tablet:forceClose`:** Toto je hypotetický event. Zjisti si v dokumentaci `aprts_tablet` nebo prohledáním jeho kód, jaká je správná funkce/event pro zavření tabletu z externího skriptu.

Hodně štěstí s tvou Godot hrou ve FiveM!
