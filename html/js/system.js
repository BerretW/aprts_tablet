// html/js/system.js

const System = {
    // === BOOT & INIT ===
    boot: (payload) => {
        AppState.currentData = payload; 
        
        // Načtení aplikací
        AppState.installedApps = (payload.installedApps && payload.installedApps.length > 0) 
            ? payload.installedApps 
            : ['store', 'settings', 'calendar'];

        // Načtení kalendáře (pokud existuje, jinak prázdný objekt)
        AppState.calendarEvents = payload.calendarEvents || {};

        AppState.currentConfig = {
            os: payload.os,
            storage: payload.storage || 1024,
            bootTime: payload.bootTime || 2000,
            wallpaper: payload.wallpaper
        };

        AppState.activeApp = null;
        UI.showAppFrame(false);
        UI.applyTheme(AppState.currentConfig.os, AppState.currentConfig.wallpaper);
        UI.toggleTablet(true);

        $('#os-content').hide();
        $('#boot-screen').show();

        const bootText = AppState.currentConfig.os === 'retro' 
            ? `> BOOT SEQUENCE INITIATED...`
            : '<div class="loader"></div>';
        
        $('#boot-logo').html(bootText);

        setTimeout(() => {
            $('#boot-screen').fadeOut(200);
            $('#os-content').fadeIn(200);
            UI.renderHomeScreen();
        }, AppState.currentConfig.bootTime);
    },

    // === CORE ===

    openApp: (appName) => {
        const app = AppState.allRegisteredApps[appName];
        if (!app) return;

        AppState.activeApp = appName;
        UI.showAppFrame(true);

        if (AppState.currentConfig.os === 'retro') {
            $('.retro-nav-bar').css('display', 'flex'); 
        }

        switch (appName) {
            case 'store':
                if (!AppState.hasInternet) { System.renderNoInternet(); } 
                else { System.renderStore(); }
                break;
            case 'settings':
                System.renderSettings();
                break;
            case 'calendar':
                System.renderCalendar();
                break;
            default:
                $.post('https://aprts_tablet/openAppRequest', JSON.stringify({ appId: appName }));
                break;
        }
    },

    goHome: () => {
        AppState.activeApp = null;
        UI.showAppFrame(false); 
        $('#app-content').empty();
        $('#calendar-modal').hide(); // Zavřít modal kdyby byl otevřený
    },

    syncToCloud: () => {
        const dataToSave = {
            installedApps: AppState.installedApps,
            background: AppState.currentConfig.wallpaper,
            calendarEvents: AppState.calendarEvents // Ukládáme i kalendář
        };
        $.post('https://aprts_tablet/syncData', JSON.stringify(dataToSave));
    },

    // === APPS ===

    // 1. APP STORE (FIXNUTO)
    renderNoInternet: () => {
        $('#app-content').html(`
            <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; height:100%; color: inherit;">
                <i class="fas fa-wifi" style="font-size: 64px; margin-bottom: 20px; opacity: 0.3;"></i>
                <h2>Offline</h2>
                <p style="opacity: 0.6;">Připojte se k Wi-Fi pro přístup.</p>
            </div>
        `);
    },

    renderStore: () => {
        let currentNet = $('#network-name').text() || "Neznámá síť";

        // Použijeme flexbox layout pro celou stránku obchodu
        let html = `
        <div style="padding: 25px; height: 100%; box-sizing: border-box; display: flex; flex-direction: column; color: white;">
            
            <div style="margin-bottom: 15px;">
                <h1 style="margin: 0; font-size: 28px;">App Store</h1>
                <span style="font-size: 13px; opacity: 0.5; display:block; margin-top:5px;"><i class="fas fa-wifi"></i> ${currentNet}</span>
            </div>

            <!-- Tady bude scrollable obsah -->
            <div style="flex-grow: 1; overflow-y: auto; padding-right: 5px;">
                <div class="store-grid">
        `;
        
        Object.keys(AppState.allRegisteredApps).forEach(key => {
            if(['store', 'settings', 'calendar'].includes(key)) return;

            let app = AppState.allRegisteredApps[key];
            const isInstalled = AppState.installedApps.includes(key);
            
            const btnText = isInstalled ? "OPEN" : "GET";
            const btnBg = isInstalled ? "rgba(255,255,255,0.1)" : "#0984e3";
            const btnColor = isInstalled ? "#aaa" : "#fff";
            
            const action = isInstalled ? "" : `onclick="System.installApp('${key}')"`;

            html += `
            <div class="store-card">
                <div style="display:flex; align-items:center; gap: 12px;">
                    <div style="background: ${app.color || '#333'}; width: 42px; height: 42px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 20px;">
                        <i class="${app.iconClass}" style="color: white;"></i>
                    </div>
                    <div>
                        <div style="font-weight: 600; font-size: 15px;">${app.label}</div>
                        <div style="font-size: 11px; opacity: 0.5;">Utility</div>
                    </div>
                </div>
                <button ${action} style="background: ${btnBg}; color: ${btnColor}; border: none; padding: 6px 16px; border-radius: 20px; font-weight: 700; font-size: 12px; cursor: pointer;">
                    ${btnText}
                </button>
            </div>`;
        });
        
        html += `</div></div></div>`; // Uzavření divů
        $('#app-content').html(html);
    },

    installApp: (appName) => {
        if (!AppState.hasInternet) return System.renderNoInternet();

        // Simulace loaderu přímo v tlačítku by byla lepší, ale pro jednoduchost překryjeme obsah
        $('#app-content').html(`
            <div style="display:flex; height:100%; justify-content:center; align-items:center; flex-direction:column; color:white;">
                <i class="fas fa-circle-notch fa-spin" style="font-size:32px; margin-bottom:15px; color: #0984e3;"></i>
                <div>Instalace...</div>
            </div>
        `);
        
        setTimeout(() => {
            if (!AppState.installedApps.includes(appName)) {
                AppState.installedApps.push(appName);
                System.syncToCloud();
            }
            System.renderStore();
        }, 1000);
    },

    // 2. KALENDÁŘ (S EVENTS)
    renderCalendar: () => {
        let date = new Date();
        let days = ['Ne', 'Po', 'Út', 'St', 'Čt', 'Pá', 'So'];
        let dayName = days[date.getDay()];
        let fullDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
        
        let html = `
        <div style="padding: 20px; height: 100%; display: flex; flex-direction: column; color: inherit; box-sizing: border-box;">
            <div style="text-align: center; margin-bottom: 20px;">
                <h1 style="font-size: 60px; margin: 0; font-weight: 300;">${date.getDate()}</h1>
                <h3 style="margin: 0; text-transform: uppercase; opacity: 0.7;">${dayName}</h3>
            </div>
            
            <div style="flex-grow: 1; overflow-y: hidden;">
                <div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 8px; padding: 10px;">
                    ${days.map(d => `<div style="text-align:center; font-weight:bold; opacity:0.5; font-size:12px;">${d}</div>`).join('')}
        `;
        
        // Generování dní (1-30)
        for(let i=1; i<=30; i++) {
            let isToday = (i === date.getDate());
            
            // Klíč pro uložení události (např "16-12-2025")
            // Pro jednoduchost v tomto příkladu použijeme fixní rok a měsíc z JS Date
            let eventKey = `${i}-${date.getMonth()+1}-${date.getFullYear()}`;
            let hasEvent = AppState.calendarEvents[eventKey] ? true : false;

            let bg = isToday ? '#e84393' : 'rgba(255,255,255,0.05)';
            let color = isToday ? 'white' : 'inherit';
            
            html += `
                <div class="calendar-day" onclick="System.openCalendarModal(${i})" style="background: ${bg}; color: ${color};">
                    ${i}
                    ${hasEvent ? '<div class="event-dot"></div>' : ''}
                </div>`;
        }

        // Výpis události pro dnešek
        let todayKey = `${date.getDate()}-${date.getMonth()+1}-${date.getFullYear()}`;
        let todayEvent = AppState.calendarEvents[todayKey] || "Žádné plány";

        html += `
                </div>
                <div style="margin-top: 20px; padding: 20px; background: rgba(255,255,255,0.05); border-radius: 12px;">
                    <h4 style="margin:0 0 5px 0; color: #e84393;">Dnešní událost:</h4>
                    <p style="margin:0; opacity: 0.8; font-size: 14px;">${todayEvent}</p>
                </div>
            </div>
        </div>`;
        
        $('#app-content').html(html);
    },

    openCalendarModal: (day) => {
        let date = new Date();
        // Uložíme si aktuálně editovaný den do globální proměnné (nebo do atributu modalu)
        AppState.editingDateKey = `${day}-${date.getMonth()+1}-${date.getFullYear()}`;
        
        let existingEvent = AppState.calendarEvents[AppState.editingDateKey] || "";

        $('#modal-date-title').text(`Plán na ${day}. ${date.getMonth()+1}.`);
        $('#event-input').val(existingEvent);
        
        // Zobrazit modal
        $('#calendar-modal').css('display', 'flex').hide().fadeIn(150);
        $('#event-input').focus();
    },

    saveCalendarEvent: () => {
        let val = $('#event-input').val();
        
        if (AppState.editingDateKey) {
            if (val.trim() === "") {
                delete AppState.calendarEvents[AppState.editingDateKey];
            } else {
                AppState.calendarEvents[AppState.editingDateKey] = val;
            }
            
            // Uložit do DB a překreslit
            System.syncToCloud();
            System.renderCalendar();
            $('#calendar-modal').fadeOut(150);
        }
    },

    // 3. SETTINGS
    renderSettings: () => {
        // ... (Zůstává stejné jako v předchozí verzi, funguje dobře) ...
         let storageUsed = AppState.installedApps.length * 50; 
        let storageTotal = AppState.currentConfig.storage;
        let percent = Math.min((storageUsed / storageTotal) * 100, 100);
        
        $('#app-content').html(`
        <div style="padding: 40px; color: inherit;">
            <h1>Nastavení</h1>
            <hr style="opacity: 0.2;">
            <div style="margin-top:20px; background: rgba(255,255,255,0.05); padding: 20px; border-radius: 10px;">
                <p><strong>Úložiště:</strong> ${storageUsed} / ${storageTotal} MB</p>
                <div style="background: #333; height: 10px; border-radius: 5px; overflow:hidden;">
                    <div style="width:${percent}%; background: #0984e3; height:100%;"></div>
                </div>
            </div>
            <button onclick="System.factoryReset()" style="margin-top:40px; background:#d63031; border:none; color:white; padding:10px 20px; border-radius:5px; cursor:pointer;">Tovární nastavení</button>
        </div>
        `);
    },
    
    factoryReset: () => {
        AppState.installedApps = ['store', 'settings', 'calendar'];
        AppState.calendarEvents = {};
        System.syncToCloud();
        System.boot(AppState.currentData);
    }
};