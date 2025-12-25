tool
extends Node

# ==============================================================================
# NASTAVENÍ APLIKACE (App Settings)
# ==============================================================================
# Název, který se zobrazí v tabletu pod ikonkou
export(String) var app_label = "Moje Hra"

# Unikátní ID aplikace (používej jen malá písmena a podtržítka, např. "flappy_bird")
export(String) var app_id = "moje_hra"

# FontAwesome ikona (např. "fas fa-gamepad", "fas fa-coins")
export(String) var fa_icon = "fas fa-gamepad"

# Barva ikonky v tabletu (HEX)
export(Color) var app_color = Color("#f1c40f")

# ==============================================================================
# NASTAVENÍ EXPORTU (Build Settings)
# ==============================================================================
# Název složky resource na serveru (např. "aprts_tablet_game")
export(String) var resource_name = "aprts_tablet_game"

# Cesta, kam jsi vyexportoval HTML5 z Godotu (obsahuje index.html)
export(String, DIR) var export_source_path = "res://export_temp"

# Cesta, kam se má vygenerovat hotový FiveM resource
export(String, DIR) var output_folder = "res://build"

# ==============================================================================
# AKCE GENERACE
# ==============================================================================
export(bool) var generate_resource = false setget _on_generate

func _on_generate(value):
	if value:
		if app_id == "" or resource_name == "":
			print("[FiveMBuilder] CHYBA: Musíš vyplnit 'App ID' a 'Resource Name'!")
			generate_resource = false
			return
			
		print("--- ZAČÍNÁM GENERACI RESOURCE: " + app_label + " ---")
		generate_structure()
		print("--- HOTOVO! Resource byl vytvořen v: " + output_folder + "/" + resource_name + " ---")
		print("--- Nezapomeň upravit 'client.lua' pro načítání dat. ---")
		generate_resource = false

func generate_structure():
	var dir = Directory.new()
	var base_path = output_folder + "/" + resource_name
	
	# 1. Vytvoření adresářové struktury
	if not dir.dir_exists(base_path):
		dir.make_dir_recursive(base_path)
	if not dir.dir_exists(base_path + "/web/game"):
		dir.make_dir_recursive(base_path + "/web/game")
		
	# 2. Kopírování a oprava HTML exportu
	copy_and_patch_export(base_path + "/web/game")
	
	# 3. Generování FiveM souborů
	save_file(base_path + "/fxmanifest.lua", get_fxmanifest())
	save_file(base_path + "/client.lua", get_client_lua())
	save_file(base_path + "/web/wrapper.html", get_wrapper_html())
	save_file(base_path + "/web/wrapper.js", get_wrapper_js())

# --- KOPÍROVÁNÍ A PATCHOVÁNÍ ---
func copy_and_patch_export(target_dir):
	var dir = Directory.new()
	if dir.open(export_source_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var source = export_source_path + "/" + file_name
				var dest = target_dir + "/" + file_name
				
				# Pokud je to HTML, opravíme ho. Ostatní jen zkopírujeme.
				if file_name.ends_with(".html"):
					patch_html_file(source, dest)
				else:
					dir.copy(source, dest)
			file_name = dir.get_next()
	else:
		print("[FiveMBuilder] CHYBA: Nemohu najít zdrojovou složku exportu: " + export_source_path)

func patch_html_file(source_path, dest_path):
	var f = File.new()
	if f.open(source_path, File.READ) != OK:
		print("[FiveMBuilder] CHYBA: Nelze číst soubor index.html")
		return

	var content = f.get_as_text()
	f.close()
	
	# 1. CSS Fix: Průhledné pozadí a skrytí posuvníků
	content = content.replace("background-color: black;", "background-color: transparent; overflow: hidden;")
	content = content.replace("#canvas {", "#canvas { width: 100%; height: 100%;")
	
	# 2. JS Focus Fix: Aby fungovalo ovládání klávesnicí v Iframe
	var focus_fix = """
					initializing = false;
					// --- FIVEM FOCUS FIX START ---
					const canvas = document.getElementById('canvas');
					if(canvas) {
						canvas.focus();
						window.focus();
						canvas.addEventListener('click', function() { 
							window.focus(); 
							canvas.focus(); 
						});
					}
					// --- FIVEM FOCUS FIX END ---
	"""
	content = content.replace("initializing = false;", focus_fix)
	
	f.open(dest_path, File.WRITE)
	f.store_string(content)
	f.close()

func save_file(path, content):
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(content)
	f.close()

# ==============================================================================
# GENERÁTORY OBSAHU SOUBORŮ
# ==============================================================================

func get_fxmanifest():
	return """fx_version 'cerulean'
lua54 'yes'

name '""" + resource_name + """'
description 'Godot Game App'
author 'FiveMBuilder'
version '1.0.0'
games {"gta5"}

client_scripts { 'client.lua' }

files {
	'web/wrapper.html',
	'web/wrapper.js',
	'web/game/*',
}

dependencies { 'aprts_tablet' }
"""

func get_client_lua():
	var hex_color = "#" + app_color.to_html(false)
	return """local APP_ID = '""" + app_id + """'
local APP_LABEL = '""" + app_label + """'

-- 1. REGISTRACE APLIKACE DO TABLETU
CreateThread(function()
	Wait(1000)
	exports['aprts_tablet']:RegisterApp(APP_ID, APP_LABEL, '""" + fa_icon + """', '""" + hex_color + """', APP_ID..':open', nil, 30, 'all')
end)

local function LoadWebFile(fileName)
	return LoadResourceFile(GetCurrentResourceName(), 'web/' .. fileName)
end

-- 2. OTEVŘENÍ APLIKACE (LOAD)
RegisterNetEvent(APP_ID..':open', function(serial)
	-- [TODO]: Zde načti data pro hráče (z DB, Configu, atd.)
	-- Příklad: local data = lib.callback.await('muj_script:getData', false)
	local myGameData = "{}" -- Zatím posíláme prázdný objekt

	local html = LoadWebFile('wrapper.html')
	if not html then 
		print('^1[GodotApp] Error: wrapper.html not found^0')
		return 
	end

	-- Nahrazení placeholderů
	html = html:gsub('{{SERIAL}}', serial)
	
	-- Bezpečné vložení JSON dat do HTML atributu
	local safeJson = tostring(myGameData):gsub('"', '&quot;')
	html = html:gsub('{{GAME_DATA}}', safeJson)

	TriggerEvent('aprts_tablet:loadContent', html)
end)

-- 3. ZPRACOVÁNÍ AKCÍ Z HRY (SAVE, CLOSE & CUSTOM)
RegisterNetEvent(APP_ID..':handleAction', function(action, data)
	local serial = data.serial
	
	if action == 'saveGame' then
		-- [TODO]: Hra chce uložit data.
		-- data.gameData obsahuje JSON objekt z Godotu.
		print('^2[GodotApp] Ukládám hru pro serial: ' .. serial .. '^0')
		
		-- TriggerServerEvent('muj_script:saveData', serial, data.gameData)
		TriggerEvent(APP_ID..':onGameSave', serial, data.gameData)

	elseif action == 'closeApp' then
		-- [NOVÉ]: Hra požádala o zavření tabletu
		print('^3[GodotApp] Zavírám aplikaci.^0')
		
		-- Zde zavolej funkci pro zavření tabletu. (Uprav dle verze tvého tabletu)
		-- exports['aprts_tablet']:Close()
		-- nebo
		TriggerEvent('aprts_tablet:forceClose') 

	elseif action == 'customAction' then
		-- [TODO]: Hra poslala specifickou akci
		local actionName = data.action
		local payload = data.payload
		if actionName == 'closeApp' then
			print('^3[GodotApp] Zavírám aplikaci.^0')
			TriggerEvent('aprts_tablet:forceClose') 
			return
		end
		print('^3[GodotApp] Custom Action: ' .. actionName .. '^0')
		
		TriggerEvent(APP_ID..':onCustomAction', serial, actionName, payload)
	end
end)
"""

func get_wrapper_html():
	return """<style>
	.app-wrapper { 
		width: 100%; 
		height: 100%; 
		display: flex; 
		flex-direction: column; 
		background-color: transparent; 
		overflow: hidden; 
	}
	#godot-frame { 
		flex: 1; 
		border: none; 
		width: 100%; 
		height: 100%; 
	}
</style>
<div class="app-wrapper">
	<!-- Skrytá pole pro přenos dat z LUA do JS -->
	<input type="hidden" id="app-serial" value="{{SERIAL}}">
	<input type="hidden" id="app-data" value="{{GAME_DATA}}">
	
	<!-- Iframe s hrou -->
	<iframe id="godot-frame" src="nui://""" + resource_name + """/web/game/index.html" allowtransparency="true"></iframe>
</div>
<script src="nui://""" + resource_name + """/web/wrapper.js"></script>
"""

func get_wrapper_js():
	return """var GameApp = {
	serial: null,
	gameData: {},
	
	init: function() {
		// Načtení serialu
		var serEl = document.getElementById('app-serial');
		if(serEl) this.serial = serEl.value;
		
		// Načtení dat hry
		var dataEl = document.getElementById('app-data');
		if(dataEl) {
			try { 
				this.gameData = JSON.parse(dataEl.value); 
			} catch (e) { 
				console.log("[GodotWrapper] Chyba parsování dat, začínám s čistým stavem.");
				this.gameData = {}; 
			}
		}
		
		// Posloucháme zprávy z Godotu
		window.addEventListener('message', this.handleMessage);
	},
	
	handleMessage: function(event) {
		if (!event.data) return;
		
		// 1. Godot se načetl a chce data
		if (event.data.type === 'GODOT_READY') {
			var iframe = document.getElementById('godot-frame');
			if (iframe && iframe.contentWindow) {
				iframe.contentWindow.postMessage({ 
					type: 'LOAD_GAME', 
					data: GameApp.gameData 
				}, '*');
			}
		
		// 2. Godot chce uložit hru (Full Save)
		} else if (event.data.type === 'SAVE_GAME') {
			System.pluginAction('""" + app_id + """', 'saveGame', {
				serial: GameApp.serial,
				gameData: event.data.data
			});
			
		// 3. Godot chce zavřít tablet (Close App)
		} else if (event.data.type === 'CLOSE_APP') {
			System.pluginAction('""" + app_id + """', 'closeApp', {});

		// 4. Godot posílá specifickou akci (Custom Action)
		} else if (event.data.type === 'CUSTOM_ACTION') {
			System.pluginAction('""" + app_id + """', 'customAction', {
				serial: GameApp.serial,
				action: event.data.data.action,
				payload: event.data.data.payload
			});
		}
	}
};

// Spuštění
GameApp.init();
"""
