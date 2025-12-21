System.registerModule("settings", {
  label: "Nastavení",
  icon: "fas fa-cog",
  color: "#636e72",

  render: function () {
    if (!AppState.savedNetworks) AppState.savedNetworks = {};

    if (AppState.currentConfig.os === "retro") {
      this.renderRetro();
    } else {
      this.renderModern();
    }
  },

  // ==========================================================================
  // MODERNÍ DESIGN
  // ==========================================================================
  renderModern: function () {
    const isChecked = AppState.userSettings && AppState.userSettings.showWifiPct ? "checked" : "";
    const isLocked = AppState.currentData.isLocked;
    const pinDisplay = "••••";
    
    // Vygenerování HTML pro uložené sítě
    let savedNetworksHtml = "";
    const savedKeys = Object.keys(AppState.savedNetworks);
    if (savedKeys.length === 0) {
        savedNetworksHtml = `<div style="padding:15px; text-align:center; opacity:0.5; font-size:12px;">Žádná uložená hesla</div>`;
    } else {
        savedKeys.forEach(ssid => {
            savedNetworksHtml += `
                <div style="padding: 12px 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                    <div style="display:flex; align-items:center; gap:10px;">
                        <i class="fas fa-save" style="font-size:12px; opacity:0.7;"></i>
                        <span>${ssid}</span>
                    </div>
                    <button onclick="System.Apps.settings.forgetNetwork('${ssid}')" style="background:rgba(214, 48, 49, 0.2); color:#ff7675; border:none; padding:5px 10px; border-radius:6px; cursor:pointer; font-size:10px;">
                        Zapomenout
                    </button>
                </div>
            `;
        });
    }

    $("#app-content").html(`
        <div style="padding: 40px; height: 100%; box-sizing: border-box; overflow-y: auto;">
            <h1 style="margin-top: 0;">Nastavení</h1>
            
            <!-- WI-FI MANAGEMENT -->
            <div style="margin-top: 20px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Wi-Fi a Sítě</h3>
                <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    
                    <!-- Přepínač procent -->
                    <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                        <span>Zobrazit procenta signálu</span>
                        <label class="switch">
                          <input type="checkbox" id="toggle-wifi-pct" ${isChecked} onchange="System.Apps.settings.toggleWifiPct(this)">
                          <span class="slider round"></span>
                        </label>
                    </div>

                    <!-- Sekce dostupných sítí (načte se AJAXem) -->
                    <div style="background:rgba(0,0,0,0.2); border-bottom: 1px solid rgba(255,255,255,0.05);">
                        <div style="padding:10px 15px; font-size:11px; opacity:0.6; text-transform:uppercase; background:rgba(255,255,255,0.02); display:flex; justify-content:space-between;">
                            <span>Dostupné sítě v okolí</span>
                            <i class="fas fa-sync-alt fa-spin" id="wifi-scanner-icon"></i>
                        </div>
                        <div id="wifi-list-container">
                            <div style="padding:15px; text-align:center; font-size:12px; opacity:0.5;">Hledání sítí...</div>
                        </div>
                    </div>
                    
                    <!-- Uložené sítě -->
                    <div style="background:rgba(0,0,0,0.2);">
                        <div style="padding:10px 15px; font-size:11px; opacity:0.6; text-transform:uppercase; background:rgba(255,255,255,0.02);">Uložená hesla</div>
                        ${savedNetworksHtml}
                    </div>
                </div>
            </div>

            <!-- ÚLOŽIŠTĚ -->
            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Úložiště</h3>
                ${this.getStorageHtml()}
            </div>

            <!-- BATERIE -->
            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Využití baterie</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);">
                    <div style="height: 150px; width: 100%;">
                        <canvas id="settingsBatteryChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- ZABEZPEČENÍ -->
            <div style="margin-top: 30px;">
                <h3 style="opacity:0.7; font-size:12px; text-transform:uppercase;">Zabezpečení</h3>
                <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                        <div>
                            <div style="font-weight:bold;">Vyžadovat PIN</div>
                            <div style="font-size:11px; opacity:0.6;">Při spuštění vyžadovat kód</div>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="toggle-lock" ${isLocked ? "checked" : ""} onchange="System.Apps.settings.toggleLock(this)">
                            <span class="slider round"></span>
                        </label>
                    </div>

                    <div style="padding: 15px; display:flex; justify-content:space-between; align-items:center;">
                        <div>
                            <div style="font-weight:bold;">Změnit PIN kód</div>
                            <div style="font-size:11px; opacity:0.6;">Aktuální: <span style="font-family: monospace; letter-spacing: 2px;">${pinDisplay}</span></div>
                        </div>
                        <button onclick="System.Apps.settings.changePin()" style="background: rgba(255,255,255,0.1); border:none; color:white; padding:8px 15px; border-radius:6px; cursor:pointer; font-weight:bold;">
                            Upravit
                        </button>
                    </div>
                </div>
            </div>

             <!-- O SYSTÉMU -->
            <div style="margin-top: 30px; margin-bottom: 40px;">
                 <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden; padding: 15px; display:flex; justify-content:space-between;">
                    <span>Serial</span>
                    <span style="opacity: 0.5; font-family: monospace;">${AppState.currentData.serial || "N/A"}</span>
                 </div>
            </div>
        </div>
    `);

    this.renderBatteryChart();
    
    // Spustíme skenování sítí
    this.scanNetworks();
  },

  // ==========================================================================
  // FUNKCE PRO SKENOVÁNÍ SÍTÍ
  // ==========================================================================
  scanNetworks: function() {
      // Zavoláme LUA callback 'getWifiList'
      $.post('https://aprts_tablet/getWifiList', JSON.stringify({}), function(networks) {
          
          let container = $("#wifi-list-container");
          $("#wifi-scanner-icon").removeClass("fa-spin").hide(); // Zastavíme točící ikonu
          
          if(!networks || networks.length === 0) {
              container.html(`<div style="padding:15px; text-align:center; opacity:0.5; font-size:12px;">Žádné sítě v dosahu.</div>`);
              return;
          }

          let html = "";
          // Aktuální připojená síť (z status baru)
          let currentConnected = $("#network-name").text().split('(')[0].trim();

          networks.forEach(net => {
              let isLocked = net.auth;
              let isConnected = (currentConnected === net.ssid);
              let iconColor = isConnected ? "#00b894" : (isLocked ? "#fdcb6e" : "#b2bec3");
              let iconClass = isLocked ? "fa-lock" : "fa-wifi";
              
              // Tlačítko Připojit nebo Text Připojeno
              let actionBtn = "";
              if (isConnected) {
                  actionBtn = `<span style="font-size:10px; color:#00b894; font-weight:bold;">PŘIPOJENO</span>`;
              } else {
                  // Pokud je zamčená, voláme connectToProtectedWifi, jinak connectToWifi (bez hesla)
                  let clickAction = isLocked ? `System.connectToProtectedWifi('${net.ssid}')` : `System.connectToProtectedWifi('${net.ssid}')`; 
                  // Poznámka: connectToProtectedWifi v system.js už zvládá otevření dialogu, 
                  // ale pokud by síť byla open, server to ověří i bez hesla.
                  // Pro jednoduchost voláme stejnou funkci, user prostě odklepne prázdné heslo nebo upravíme system.js
                  
                  actionBtn = `<button onclick="${clickAction}" style="background:rgba(255,255,255,0.1); border:none; color:white; padding:5px 10px; border-radius:6px; cursor:pointer; font-size:10px;">Připojit</button>`;
              }

              html += `
                <div style="padding: 12px 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                    <div style="display:flex; align-items:center; gap:12px;">
                        <i class="fas ${iconClass}" style="font-size:14px; color:${iconColor}; width:15px; text-align:center;"></i>
                        <div style="display:flex; flex-direction:column;">
                            <span style="font-weight:600; font-size:13px;">${net.ssid}</span>
                            <span style="font-size:10px; opacity:0.5;">Signál: ${net.level}% ${net.type === 'public' ? '(Veřejná)' : ''}</span>
                        </div>
                    </div>
                    ${actionBtn}
                </div>
              `;
          });
          
          container.html(html);
      });
  },

  // ==========================================================================
  // RETRO DESIGN (Zjednodušený)
  // ==========================================================================
  renderRetro: function () {
    const showWifi = AppState.userSettings && AppState.userSettings.showWifiPct;
    const isLocked = AppState.currentData.isLocked;

    // Generování seznamu uložených
    let savedList = "";
    Object.keys(AppState.savedNetworks).forEach(ssid => {
        savedList += `<div>- ${ssid} <span style="cursor:pointer; color:#ff0000;" onclick="System.Apps.settings.forgetNetwork('${ssid}')">[DEL]</span></div>`;
    });
    if(savedList === "") savedList = "<div>> NO_SAVED_NETWORKS</div>";

    $("#app-content").html(`
        <div style="padding: 20px; font-family: 'Courier New', monospace; color: #00ff00; height: 100%; box-sizing: border-box; overflow-y: auto;">
            <div style="border-bottom: 2px dashed #00ff00; margin-bottom: 20px; padding-bottom: 10px;">
                > CONFIG_SYS.EXE loaded.<br>
                > USER: ADMIN
            </div>

            <!-- WIFI -->
            <div style="margin-bottom: 20px;">
                <div style="background: #001100; border: 1px solid #004400; padding: 10px; margin-bottom: 5px;">
                    [ NETWORKING ]
                </div>
                <div style="cursor: pointer;" onclick="document.getElementById('retro-wifi-check').click()">
                    [<input type="checkbox" id="retro-wifi-check" ${showWifi ? "checked" : ""} onchange="System.Apps.settings.toggleWifiPct(this)" style="accent-color: #00ff00;">] SHOW_SIGNAL_PCT
                </div>
                
                <div style="margin-top:10px; padding-top:5px; border-top:1px dashed #004400;">
                     <div>> AVAILABLE_NETWORKS: <span id="retro-loading" style="animation: blink 1s infinite;">SCANNING...</span></div>
                     <div id="retro-wifi-list" style="padding-left:10px; margin-bottom:10px;"></div>
                </div>

                <div style="margin-top:10px; border-top:1px dashed #004400; padding-top:5px;">
                    <div>> KNOWN_HOSTS:</div>
                    <div style="padding-left:10px; font-size:12px;">
                        ${savedList}
                    </div>
                </div>
            </div>

            <!-- SECURITY & INFO (Stejné jako předtím) -->
             <div style="margin-bottom: 20px;">
                <div style="background: #001100; border: 1px solid #004400; padding: 10px; margin-bottom: 5px;">
                    [ SECURITY_PROTOCOL ]
                </div>
                <div style="margin-bottom: 10px; cursor: pointer;" onclick="document.getElementById('retro-lock-check').click()">
                     [<input type="checkbox" id="retro-lock-check" ${isLocked ? "checked" : ""} onchange="System.Apps.settings.toggleLock(this)" style="accent-color: #00ff00;">] BOOT_LOCK_ENABLED
                </div>
                <div style="display: flex; align-items: center; gap: 10px;">
                    <span>PIN_CODE: ****</span>
                    <button onclick="System.Apps.settings.changePin()" style="background: black; color: #00ff00; border: 1px solid #00ff00; padding: 2px 10px; cursor: pointer; font-family: inherit; text-transform: uppercase;">
                        [ MODIFY ]
                    </button>
                </div>
            </div>
            
            <div style="margin-top: 30px; border-top: 1px solid #004400; padding-top: 10px;">
                HW_SERIAL: ${AppState.currentData.serial || "UNKNOWN"}<br>
                BATT_LVL: ${AppState.batteryHistory[AppState.batteryHistory.length - 1].value}%
            </div>
        </div>
    `);

    // Retro Scan
    $.post('https://aprts_tablet/getWifiList', JSON.stringify({}), function(networks) {
        $("#retro-loading").remove();
        let html = "";
        if(!networks || networks.length === 0) html = "<div>> NO_SIGNAL_FOUND</div>";
        else {
            networks.forEach(net => {
                let lockStr = net.auth ? "[LOCKED]" : "[OPEN]";
                html += `<div style="cursor:pointer;" onclick="System.connectToProtectedWifi('${net.ssid}')">> ${net.ssid} ${lockStr} (${net.level}%)</div>`;
            });
        }
        $("#retro-wifi-list").html(html);
    });
  },

  // --- HELPERS (Stejné jako předtím) ---
  forgetNetwork: function(ssid) {
      if(AppState.savedNetworks[ssid]) {
          delete AppState.savedNetworks[ssid];
          System.syncToCloud();
          this.render();
          System.API.showNotification({title: "Info", text: `Síť ${ssid} zapomenuta.`, icon: "info", toast: true});
      }
  },

  getStorageHtml: function() {
    let storageUsed = 0;
    AppState.installedApps.forEach((appName) => {
      let app = AppState.allRegisteredApps[appName];
      storageUsed += (app && app.size) ? app.size : 50;
    });
    storageUsed = storageUsed.toFixed(0);
    let storageTotal = AppState.currentConfig.storage || 1024;
    let percent = Math.min((storageUsed / storageTotal) * 100, 100);

    return `
        <div style="background: rgba(255,255,255,0.05); padding: 20px; border-radius: 12px;">
            <div style="display:flex; justify-content:space-between; margin-bottom: 10px;">
                <span>Využito</span>
                <span style="opacity: 0.7;">${storageUsed} MB / ${storageTotal} MB</span>
            </div>
            <div style="background: rgba(255,255,255,0.1); height: 8px; border-radius: 4px; overflow:hidden;">
                <div style="width:${percent}%; background: ${percent > 80 ? "#d63031" : "#0984e3"}; height:100%; transition: width 1s;"></div>
            </div>
        </div>
    `;
  },

  renderBatteryChart: function () {
     // (Kod grafu zůstává stejný jako v předchozí verzi...)
     const chartLabels = AppState.batteryHistory.map((item) => item.time);
     const chartData = AppState.batteryHistory.map((item) => item.value);
     System.API.renderChart({
        targetId: "settingsBatteryChart",
        config: {
           type: "line",
           data: {
              labels: chartLabels,
              datasets: [{label: "Baterie (%)", data: chartData, borderColor: "#00b894", backgroundColor: "rgba(0, 184, 148, 0.2)", borderWidth: 2, tension: 0.3, fill: true, pointRadius: 2, pointHoverRadius: 5}],
           },
           options: {
              responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } },
              scales: { x: { display: true, ticks: { color: "rgba(255,255,255,0.3)", font: { size: 10 }, maxTicksLimit: 6 }, grid: { display: false } }, y: { beginAtZero: true, max: 100, grid: { color: "rgba(255,255,255,0.05)" } } }, animation: false,
           },
        },
     });
  },

  toggleLock: function (el) { /* Původní kód */ 
    const newState = el.checked; AppState.currentData.isLocked = newState; $.post("https://aprts_tablet/setLockState", JSON.stringify({ locked: newState })); if (AppState.currentConfig.os === "retro") { System.playSound("click"); } else { System.API.showNotification({ title: "Zabezpečení", text: newState ? "Tablet uzamčen." : "Tablet odemčen.", icon: newState ? "success" : "warning", toast: true }); }
  },
  changePin: function () { /* Původní kód */ 
    const isRetro = AppState.currentConfig.os === "retro"; const bg = isRetro ? "#000000" : "#1e1e1e"; const fg = isRetro ? "#00ff00" : "#ffffff"; Swal.fire({ title: "Zadejte nový PIN", input: "text", inputAttributes: { maxlength: 4 }, showCancelButton: true, background: bg, color: fg, confirmButtonColor: isRetro ? "#000" : "#3085d6", cancelButtonColor: isRetro ? "#000" : "#d33", inputValidator: (value) => { if (!/^\d{4}$/.test(value)) return "Musíte zadat 4 číslice!"; }, }).then((result) => { if (result.isConfirmed) { const newPin = result.value; AppState.currentData.pin = newPin; $.post("https://aprts_tablet/setPin", JSON.stringify({ pin: newPin })); if (isRetro) { System.playSound("notify"); this.renderRetro(); } else { System.API.showNotification({ title: "PIN změněn", text: `Nový kód: ${newPin}`, icon: "success", toast: true }); this.renderModern(); } } });
  },
  toggleWifiPct: function (checkbox) { /* Původní kód */ 
    if (!AppState.userSettings) AppState.userSettings = {}; AppState.userSettings.showWifiPct = checkbox.checked; let netNameEl = $("#network-name"); let currentText = netNameEl.text().split("(")[0].trim(); if (checkbox.checked) netNameEl.text(currentText + " (...)"); else netNameEl.text(currentText);
  },
});