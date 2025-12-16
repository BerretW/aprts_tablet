System.registerModule('store', {
    label: 'App Store',
    icon: 'fas fa-store',
    color: '#0984e3',
    size: 10, // Samotný Store zabírá jen 10 MB

    render: function() {
        // 1. Kontrola internetu
        if (!AppState.hasInternet) {
            return this.renderNoInternet();
        }

        // 2. Příprava proměnných
        let currentNet = $("#network-name").text() || "Neznámá síť";
        let currentOS = AppState.currentConfig.os; // 'retro' nebo 'modern'
        let totalStorage = AppState.currentConfig.storage || 1024;

        // 3. Výpočet využitého místa
        let usedSpace = 0;
        AppState.installedApps.forEach(appName => {
            let appData = AppState.allRegisteredApps[appName];
            // Pokud aplikace nemá definovanou velikost, počítáme defaultně 50 MB
            usedSpace += (appData && appData.size) ? appData.size : 50;
        });
        
        let freeSpace = totalStorage - usedSpace;

        // 4. Začátek HTML struktury
        let html = `
            <div style="padding: 30px; height: 100%; box-sizing: border-box; display: flex; flex-direction: column;">
                <!-- HLAVIČKA -->
                <div style="margin-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 10px; display: flex; justify-content: space-between; align-items: flex-end;">
                    <div>
                        <h1 style="margin: 0; font-size: 32px; font-weight: 700;">App Store</h1>
                        <span style="font-size: 13px; opacity: 0.5;">
                            <i class="fas fa-wifi"></i> ${currentNet}
                        </span>
                    </div>
                    <div style="text-align: right;">
                        <div style="font-size: 12px; opacity: 0.7; text-transform: uppercase;">Úložiště</div>
                        <div style="font-weight: bold; color: ${freeSpace < 100 ? '#ff7675' : '#55efc4'}">
                            ${freeSpace} MB volno
                        </div>
                    </div>
                </div>

                <!-- GRID APLIKACÍ -->
                <div style="flex-grow: 1; overflow-y: auto; padding-right: 5px;">
                    <div class="store-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
        `;

        // 5. Iterace přes všechny registrované aplikace
        Object.keys(AppState.allRegisteredApps).forEach((key) => {
            // Skryjeme interní systémové moduly (Store, Settings, Calendar atd.),
            // pokud chceme, aby se aktualizovaly, museli bychom tuto podmínku odstranit.
            // Obvykle ale systémové aplikace v App Store nezobrazujeme.
            if (System.Apps[key]) return; 

            let app = AppState.allRegisteredApps[key];
            const isInstalled = AppState.installedApps.includes(key);
            const appSize = app.size || 50;

            // --- LOGIKA KOMPATIBILITY ---
            let isCompatible = true;
            // Pokud je supportedOS definováno a není to "all"
            if (app.supportedOS && app.supportedOS !== 'all') {
                if (Array.isArray(app.supportedOS)) {
                    // Pokud je to pole (např. ['modern', 'pro']), zkontrolujeme zda obsahuje náš OS
                    if (!app.supportedOS.includes(currentOS)) isCompatible = false;
                } else {
                    // Pokud je to string
                    if (app.supportedOS !== currentOS) isCompatible = false;
                }
            }

            // --- LOGIKA MÍSTA ---
            // Máme místo NA TUTO aplikaci?
            let hasSpace = freeSpace >= appSize;

            // --- STAV TLAČÍTKA ---
            let btnText = "STÁHNOUT";
            let btnBg = "#0984e3"; // Modrá
            let btnAction = `System.Apps.store.installApp('${key}')`;
            let isDisabled = false;
            let statusLabel = `${appSize} MB`;
            let labelColor = "opacity: 0.5;";

            if (isInstalled) {
                btnText = "OTEVŘÍT";
                btnBg = "rgba(255,255,255,0.1)";
                btnAction = `System.openApp('${key}')`;
                statusLabel = "Nainstalováno";
            } else if (!isCompatible) {
                btnText = "NEPODPOROVÁNO";
                btnBg = "#2d3436"; // Tmavá šedá
                isDisabled = true;
                btnAction = "";
                statusLabel = "Inkompatibilní OS";
                labelColor = "color: #ff7675;"; // Červená
            } else if (!hasSpace) {
                btnText = "PLNÉ ÚLOŽIŠTĚ";
                btnBg = "#d63031"; // Červená
                isDisabled = true;
                btnAction = "";
                statusLabel = `Vyžaduje ${appSize} MB`;
                labelColor = "color: #fdcb6e;"; // Oranžová
            }

            // Vykreslení karty
            html += `
                <div class="store-card" style="display: flex; align-items: center; justify-content: space-between; opacity: ${isDisabled ? 0.6 : 1};">
                    <div style="display:flex; align-items:center; gap: 15px;">
                        <div style="background: ${app.color || "#333"}; width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 22px;">
                            <i class="${app.iconClass}" style="color: white;"></i>
                        </div>
                        <div>
                            <div style="font-weight: 600; font-size: 16px;">${app.label}</div>
                            <div style="font-size: 11px; ${labelColor}">${statusLabel}</div>
                        </div>
                    </div>
                    <button onclick="${btnAction}" ${isDisabled ? 'disabled' : ''} 
                        style="background: ${btnBg}; color: white; border: none; padding: 8px 15px; border-radius: 20px; font-weight: 700; font-size: 10px; cursor: ${isDisabled ? 'not-allowed' : 'pointer'}; transition: 0.2s; white-space: nowrap;">
                        ${btnText}
                    </button>
                </div>`;
        });

        html += `</div></div></div>`;
        $("#app-content").html(html);
    },

    renderNoInternet: function() {
        $("#app-content").html(`
            <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; height:100%; text-align:center;">
                <i class="fas fa-wifi" style="font-size: 64px; margin-bottom: 20px; opacity: 0.3;"></i>
                <h2>Žádné připojení</h2>
                <p style="opacity: 0.6;">App Store vyžaduje připojení k síti.</p>
                <button onclick="System.Apps.store.render()" style="margin-top:20px; background:rgba(255,255,255,0.1); border:1px solid rgba(255,255,255,0.2); color:white; padding:10px 20px; border-radius:20px; cursor:pointer;">
                    Zkusit znovu
                </button>
            </div>
        `);
    },

    installApp: function(appName) {
        // Znovu ověření internetu
        if (!AppState.hasInternet) return this.renderNoInternet();
        
        // Znovu ověření místa (pro jistotu, kdyby se stav změnil během prohlížení)
        let appData = AppState.allRegisteredApps[appName];
        let appSize = (appData && appData.size) ? appData.size : 50;
        
        // Výpočet aktuálního využití
        let usedSpace = 0;
        AppState.installedApps.forEach(k => {
            let a = AppState.allRegisteredApps[k];
            usedSpace += (a && a.size) ? a.size : 50;
        });
        let totalStorage = AppState.currentConfig.storage || 1024;
        
        if (usedSpace + appSize > totalStorage) {
            // Pokud už není místo (zobrazíme alert)
            if(System.API && System.API.showNotification) {
                System.API.showNotification({
                    title: "Chyba",
                    text: "Nedostatek místa v úložišti!",
                    icon: "error",
                    toast: true
                });
            }
            return this.render(); // Překreslit
        }

        // Zobrazení loaderu
        $("#app-content").html(`
            <div style="display:flex; height:100%; justify-content:center; align-items:center; flex-direction:column;">
                <div style="position:relative; width:60px; height:60px;">
                    <i class="fas fa-circle-notch fa-spin" style="font-size:50px; color: #0984e3; position:absolute; top:0; left:0;"></i>
                    <i class="${appData.iconClass}" style="font-size:20px; color: white; position:absolute; top:15px; left:15px;"></i>
                </div>
                <div style="font-size: 18px; margin-top: 20px; font-weight:bold;">Instalace...</div>
                <div style="font-size: 14px; opacity:0.6;">Stahování ${appData.label}</div>
            </div>
        `);
        
        // Simulace stahování
        setTimeout(() => {
            if (!AppState.installedApps.includes(appName)) {
                AppState.installedApps.push(appName);
                
                // Uložení změn na server
                System.syncToCloud();
                
                // Notifikace o úspěchu
                if(System.API && System.API.showNotification) {
                    System.API.showNotification({
                        title: "Instalace dokončena",
                        text: `${appData.label} byla nainstalována.`,
                        icon: "success",
                        toast: true
                    });
                }
            }
            // Návrat do obchodu
            this.render();
        }, 2000);
    }
});