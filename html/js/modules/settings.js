System.registerModule("settings", {
  label: "Nastavení",
  icon: "fas fa-cog",
  color: "#636e72",

  render: function () {
    // Rozcestník podle typu OS
    if (AppState.currentConfig.os === "retro") {
      this.renderRetro();
    } else {
      this.renderModern();
    }
  },

  // ==========================================================================
  // MODERNÍ DESIGN (iFruit / Android styl)
  // ==========================================================================
  renderModern: function () {
    const isChecked =
      AppState.userSettings && AppState.userSettings.showWifiPct ? "checked" : "";
    
    let storageUsed = (AppState.installedApps.length * 150).toFixed(0);
    let storageTotal = AppState.currentConfig.storage || 1024;
    let percent = Math.min((storageUsed / storageTotal) * 100, 100);
    
    const isLocked = AppState.currentData.isLocked;
    const pinDisplay = "••••"; 

    $("#app-content").html(`
        <div style="padding: 40px; height: 100%; box-sizing: border-box; overflow-y: auto;">
            <h1 style="margin-top: 0;">Nastavení</h1>
            
            <div style="margin-top: 20px; background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                    <span>Zobrazit procenta Wi-Fi</span>
                    <label class="switch">
                      <input type="checkbox" id="toggle-wifi-pct" ${isChecked} onchange="System.Apps.settings.toggleWifiPct(this)">
                      <span class="slider round"></span>
                    </label>
                </div>
            </div>

            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Úložiště</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 20px; border-radius: 12px;">
                    <div style="display:flex; justify-content:space-between; margin-bottom: 10px;">
                        <span>Využito</span>
                        <span style="opacity: 0.7;">${storageUsed} MB / ${storageTotal} MB</span>
                    </div>
                    <div style="background: rgba(255,255,255,0.1); height: 8px; border-radius: 4px; overflow:hidden;">
                        <div style="width:${percent}%; background: ${percent > 80 ? "#d63031" : "#0984e3"}; height:100%; transition: width 1s;"></div>
                    </div>
                </div>
            </div>

            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Využití baterie</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);">
                    <div style="height: 150px; width: 100%;">
                        <canvas id="settingsBatteryChart"></canvas>
                    </div>
                </div>
            </div>

            <div style="margin-top: 30px;">
                <h3 style="opacity:0.7; font-size:12px; text-transform:uppercase;">Zabezpečení</h3>
                <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                        <div>
                            <div style="font-weight:bold;">Vyžadovat PIN</div>
                            <div style="font-size:11px; opacity:0.6;">Při spuštění vyžadovat kód</div>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="toggle-lock" ${isLocked ? 'checked' : ''} onchange="System.Apps.settings.toggleLock(this)">
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

            <div style="margin-top: 30px; margin-bottom: 40px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">O systému</h3>
                 <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    <div style="padding: 15px; display:flex; justify-content:space-between;">
                        <span>Serial</span>
                        <span style="opacity: 0.5; font-family: monospace;">${AppState.currentData.serial || "N/A"}</span>
                    </div>
                 </div>
            </div>
        </div>
    `);
    
    // Vykreslení grafu pro Modern
    this.renderBatteryChart();
  },

  // ==========================================================================
  // RETRO DESIGN (Terminál / DOS styl)
  // ==========================================================================
  renderRetro: function() {
    const showWifi = AppState.userSettings && AppState.userSettings.showWifiPct;
    const isLocked = AppState.currentData.isLocked;
    
    let storageUsed = (AppState.installedApps.length * 150);
    let storageTotal = AppState.currentConfig.storage || 512;
    
    // ASCII Progress bar
    let totalBars = 20;
    let filledBars = Math.round((storageUsed / storageTotal) * totalBars);
    let barStr = "[" + "#".repeat(filledBars) + "-".repeat(totalBars - filledBars) + "]";

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
                    [<input type="checkbox" id="retro-wifi-check" ${showWifi ? 'checked' : ''} 
                      onchange="System.Apps.settings.toggleWifiPct(this)" 
                      style="accent-color: #00ff00;">] SHOW_SIGNAL_PCT
                </div>
            </div>

            <!-- SECURITY -->
            <div style="margin-bottom: 20px;">
                <div style="background: #001100; border: 1px solid #004400; padding: 10px; margin-bottom: 5px;">
                    [ SECURITY_PROTOCOL ]
                </div>
                
                <div style="margin-bottom: 10px; cursor: pointer;" onclick="document.getElementById('retro-lock-check').click()">
                     [<input type="checkbox" id="retro-lock-check" ${isLocked ? 'checked' : ''} 
                       onchange="System.Apps.settings.toggleLock(this)"
                       style="accent-color: #00ff00;">] BOOT_LOCK_ENABLED
                </div>
                
                <div style="display: flex; align-items: center; gap: 10px;">
                    <span>PIN_CODE: ****</span>
                    <button onclick="System.Apps.settings.changePin()" 
                            style="background: black; color: #00ff00; border: 1px solid #00ff00; padding: 2px 10px; cursor: pointer; font-family: inherit; text-transform: uppercase;">
                        [ MODIFY ]
                    </button>
                </div>
            </div>

            <!-- STORAGE -->
            <div style="margin-bottom: 20px;">
                <div style="background: #001100; border: 1px solid #004400; padding: 10px; margin-bottom: 5px;">
                    [ MEMORY_DUMP ]
                </div>
                <div>USED: ${storageUsed}KB / ${storageTotal}KB</div>
                <div>${barStr}</div>
            </div>

            <!-- SYSTEM INFO -->
            <div style="margin-top: 30px; border-top: 1px solid #004400; padding-top: 10px;">
                HW_SERIAL: ${AppState.currentData.serial || "UNKNOWN"}<br>
                OS_VER: 1.0.4-RETRO<br>
                BATT_LVL: ${AppState.batteryHistory[AppState.batteryHistory.length - 1].value}%
            </div>
        </div>
    `);
  },

  // Pomocná funkce pro graf (pouze Modern)
  renderBatteryChart: function() {
    const chartLabels = AppState.batteryHistory.map((item) => item.time);
    const chartData = AppState.batteryHistory.map((item) => item.value);

    System.API.renderChart({
      targetId: "settingsBatteryChart",
      config: {
        type: "line",
        data: {
          labels: chartLabels,
          datasets: [{
              label: "Baterie (%)",
              data: chartData,
              borderColor: "#00b894",
              backgroundColor: "rgba(0, 184, 148, 0.2)",
              borderWidth: 2,
              tension: 0.3,
              fill: true,
              pointRadius: 2,
              pointHoverRadius: 5,
            }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { display: true, ticks: { color: "rgba(255,255,255,0.3)", font: { size: 10 }, maxTicksLimit: 6 }, grid: { display: false } },
            y: { beginAtZero: true, max: 100, grid: { color: "rgba(255,255,255,0.05)" } },
          },
          animation: false,
        },
      },
    });
  },

  // Funkce pro přepínače
  toggleLock: function (el) {
    const newState = el.checked;
    AppState.currentData.isLocked = newState;

    $.post("https://aprts_tablet/setLockState", JSON.stringify({ locked: newState }));

    // Retro notifikace vs Modern notifikace
    if (AppState.currentConfig.os === "retro") {
        System.playSound('click'); // Jen kliknutí
    } else {
        System.API.showNotification({
            title: "Zabezpečení",
            text: newState ? "Tablet uzamčen." : "Tablet odemčen.",
            icon: newState ? "success" : "warning",
            toast: true,
        });
    }
  },

  changePin: function () {
    // Pro Retro bychom mohli použít stylovanější input, ale SweetAlert funguje všude
    // Jen upravíme barvy pokud je Retro, aby to tolik nebilo do očí
    const isRetro = AppState.currentConfig.os === "retro";
    const bg = isRetro ? "#000000" : "#1e1e1e";
    const fg = isRetro ? "#00ff00" : "#ffffff";
    const border = isRetro ? "1px solid #00ff00" : "none";

    Swal.fire({
      title: "Zadejte nový PIN",
      input: "text",
      inputAttributes: { maxlength: 4 },
      showCancelButton: true,
      background: bg,
      color: fg,
      confirmButtonColor: isRetro ? "#000" : "#3085d6",
      cancelButtonColor: isRetro ? "#000" : "#d33",
      customClass: {
          popup: isRetro ? 'retro-swal' : '' // Pokud bys chtěl extra CSS
      },
      inputValidator: (value) => {
        if (!/^\d{4}$/.test(value)) return "Musíte zadat 4 číslice!";
      },
    }).then((result) => {
      if (result.isConfirmed) {
        const newPin = result.value;
        AppState.currentData.pin = newPin;

        $.post("https://aprts_tablet/setPin", JSON.stringify({ pin: newPin }));

        if(isRetro) {
             System.playSound('notify'); 
             // U Retro jen refreshneme view, aby se to propsalo
             this.renderRetro();
        } else {
            System.API.showNotification({
                title: "PIN změněn",
                text: `Nový kód: ${newPin}`,
                icon: "success",
                toast: true,
            });
            this.renderModern();
        }
      }
    });
  },
  
  toggleWifiPct: function (checkbox) {
    if (!AppState.userSettings) AppState.userSettings = {};
    AppState.userSettings.showWifiPct = checkbox.checked;

    let netNameEl = $("#network-name");
    let currentText = netNameEl.text().split("(")[0].trim();
    if (checkbox.checked) netNameEl.text(currentText + " (...)");
    else netNameEl.text(currentText);
  },
});