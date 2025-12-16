System.registerModule('store', {
    label: 'App Store',
    icon: 'fas fa-store',
    color: '#0984e3',

    render: function() {
        if (!AppState.hasInternet) {
            return this.renderNoInternet();
        }

        let currentNet = $("#network-name").text() || "Neznámá síť";
        let html = `
            <div style="padding: 30px; height: 100%; box-sizing: border-box; display: flex; flex-direction: column;">
                <div style="margin-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 10px;">
                    <h1 style="margin: 0; font-size: 32px; font-weight: 700;">App Store</h1>
                    <span style="font-size: 13px; opacity: 0.5;"><i class="fas fa-wifi"></i> ${currentNet}</span>
                </div>
                <div style="flex-grow: 1; overflow-y: auto; padding-right: 5px;">
                    <div class="store-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
        `;

        Object.keys(AppState.allRegisteredApps).forEach((key) => {
            // Skryjeme interní systémové moduly
            if (System.Apps[key]) return; 

            let app = AppState.allRegisteredApps[key];
            const isInstalled = AppState.installedApps.includes(key);
            const btnText = isInstalled ? "OTEVŘÍT" : "STÁHNOUT";
            const btnBg = isInstalled ? "rgba(255,255,255,0.1)" : "#0984e3";
            
            // Voláme funkci modulu nebo Systemu
            const btnAction = isInstalled
                ? `System.openApp('${key}')`
                : `System.Apps.store.installApp('${key}')`; // Volání funkce v tomto modulu

            html += `
                <div class="store-card" style="display: flex; align-items: center; justify-content: space-between;">
                    <div style="display:flex; align-items:center; gap: 15px;">
                        <div style="background: ${app.color || "#333"}; width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 22px;">
                            <i class="${app.iconClass}" style="color: white;"></i>
                        </div>
                        <div>
                            <div style="font-weight: 600; font-size: 16px;">${app.label}</div>
                            <div style="font-size: 11px; opacity: 0.5;">${isInstalled ? "Nainstalováno" : "Zdarma"}</div>
                        </div>
                    </div>
                    <button onclick="${btnAction}" style="background: ${btnBg}; color: white; border: none; padding: 8px 18px; border-radius: 20px; font-weight: 700; font-size: 11px; cursor: pointer; transition: 0.2s;">
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
                <p style="opacity: 0.6;">Zkontrolujte signál Wi-Fi.</p>
            </div>
        `);
    },

    installApp: function(appName) {
        if (!AppState.hasInternet) return this.renderNoInternet();
        
        $("#app-content").html(`
            <div style="display:flex; height:100%; justify-content:center; align-items:center; flex-direction:column;">
                <i class="fas fa-circle-notch fa-spin" style="font-size:40px; margin-bottom:20px; color: #0984e3;"></i>
                <div style="font-size: 18px;">Instalace...</div>
            </div>
        `);
        
        setTimeout(() => {
            if (!AppState.installedApps.includes(appName)) {
                AppState.installedApps.push(appName);
                System.syncToCloud();
            }
            // Znovu vykreslíme store (this = tento modul)
            this.render();
        }, 1500);
    }
});