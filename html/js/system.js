/* html/js/system.js */

const System = {
    // === BOOT & INIT ===
    boot: (payload) => {
        AppState.currentData = payload; 
        
        AppState.installedApps = (payload.installedApps && payload.installedApps.length > 0) 
            ? payload.installedApps 
            : ['store', 'settings', 'calendar'];

        // Inicializace kalendáře
        AppState.calendarEvents = payload.calendarEvents || {};
        if (Array.isArray(AppState.calendarEvents)) {
             // Fix pokud by DB vracela pole místo objektu
            AppState.calendarEvents = {}; 
        }

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

        // Reset views
        $('#os-content').hide();
        $('#boot-screen').show();

        // Boot animace
        const bootText = AppState.currentConfig.os === 'retro' 
            ? `> SYSTEM CHECK... OK\n> MEMORY... OK\n> BOOTING...`
            : '<div class="boot-logo-icon"><i class="fab fa-apple" style="font-size:60px;"></i></div>';
        
        $('#boot-logo').html(bootText);

        setTimeout(() => {
            $('#boot-screen').fadeOut(300, function() {
                $('#os-content').fadeIn(300);
            });
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
                // INICIALIZACE STAVU PROHLÍŽENÍ
                let now = new Date();
                AppState.calendarView = {
                    month: now.getMonth(),
                    year: now.getFullYear()
                };
                System.renderCalendar();
                break;
            default:
                $.post('https://aprts_tablet/openAppRequest', JSON.stringify({ appId: appName }));
                break;
        }
    },

    // Funkce pro přepínání měsíců
    changeMonth: (direction) => {
        // direction je -1 (zpět) nebo 1 (vpřed)
        AppState.calendarView.month += direction;

        // Ošetření přechodu přes rok
        if (AppState.calendarView.month < 0) {
            AppState.calendarView.month = 11;
            AppState.calendarView.year -= 1;
        } else if (AppState.calendarView.month > 11) {
            AppState.calendarView.month = 0;
            AppState.calendarView.year += 1;
        }
        
        System.renderCalendar();
    },

    goHome: () => {
        AppState.activeApp = null;
        UI.showAppFrame(false); 
        $('#app-content').empty();
        $('#calendar-modal').fadeOut(100);
    },

    syncToCloud: () => {
        console.log('^3[Tablet] Synchronizace dat do cloudu...^0');
        console.log(JSON.stringify({
            installedApps: AppState.installedApps,
            background: AppState.currentConfig.wallpaper,
            calendarEvents: AppState.calendarEvents
        }));
        const dataToSave = {
            installedApps: AppState.installedApps,
            background: AppState.currentConfig.wallpaper,
            calendarEvents: AppState.calendarEvents
        };
        $.post('https://aprts_tablet/syncData', JSON.stringify(dataToSave));
    },

    // === APPS ===

    // 1. UTILS
    renderNoInternet: () => {
        $('#app-content').html(`
            <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; height:100%; text-align:center;">
                <i class="fas fa-wifi" style="font-size: 64px; margin-bottom: 20px; opacity: 0.3;"></i>
                <h2>Žádné připojení</h2>
                <p style="opacity: 0.6;">Zkontrolujte signál Wi-Fi.</p>
            </div>
        `);
    },

    // 2. STORE
    renderStore: () => {
        let currentNet = $('#network-name').text() || "Neznámá síť";

        let html = `
        <div style="padding: 30px; height: 100%; box-sizing: border-box; display: flex; flex-direction: column;">
            
            <div style="margin-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 10px;">
                <h1 style="margin: 0; font-size: 32px; font-weight: 700;">App Store</h1>
                <span style="font-size: 13px; opacity: 0.5;"><i class="fas fa-wifi"></i> ${currentNet}</span>
            </div>

            <div style="flex-grow: 1; overflow-y: auto; padding-right: 5px;">
                <div class="store-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
        `;
        
        Object.keys(AppState.allRegisteredApps).forEach(key => {
            // Skryjeme systémové, pokud už jsou nainstalované (kromě settings atd, ty v storu nechcem vůbec)
            if(['settings', 'calendar'].includes(key)) return;

            let app = AppState.allRegisteredApps[key];
            const isInstalled = AppState.installedApps.includes(key);
            
            // Styl tlačítka
            const btnText = isInstalled ? "OTEVŘÍT" : "STÁHNOUT";
            const btnBg = isInstalled ? "rgba(255,255,255,0.1)" : "#0984e3";
            const btnAction = isInstalled ? `System.openApp('${key}')` : `System.installApp('${key}')`;
            
            html += `
            <div class="store-card" style="display: flex; align-items: center; justify-content: space-between;">
                <div style="display:flex; align-items:center; gap: 15px;">
                    <div style="background: ${app.color || '#333'}; width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 22px;">
                        <i class="${app.iconClass}" style="color: white;"></i>
                    </div>
                    <div>
                        <div style="font-weight: 600; font-size: 16px;">${app.label}</div>
                        <div style="font-size: 11px; opacity: 0.5;">${isInstalled ? 'Nainstalováno' : 'Zdarma'}</div>
                    </div>
                </div>
                <button onclick="${btnAction}" style="background: ${btnBg}; color: white; border: none; padding: 8px 18px; border-radius: 20px; font-weight: 700; font-size: 11px; cursor: pointer; transition: 0.2s;">
                    ${btnText}
                </button>
            </div>`;
        });
        
        html += `</div></div></div>`;
        $('#app-content').html(html);
    },

    installApp: (appName) => {
        if (!AppState.hasInternet) return System.renderNoInternet();

        $('#app-content').html(`
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
            // Zpět do storu nebo rovnou otevřít? Otevřeme store pro feedback.
            System.renderStore();
        }, 1500);
    },

    // 3. KALENDÁŘ (Refactor)
   renderCalendar: () => {
        // Skutečný dnešek (pro zvýraznění "Dnes")
        let realDate = new Date();
        
        // Měsíc, který prohlížíme
        let viewMonth = AppState.calendarView.month;
        let viewYear = AppState.calendarView.year;

        // Výpočty pro grid
        let daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        let firstDayIndex = new Date(viewYear, viewMonth, 1).getDay(); // 0 = Neděle
        
        // V ČR začínáme týden Pondělkem (1), takže posuneme indexy
        // Neděle (0) se stane 6, ostatní se posunou o -1
        let czechFirstDayIndex = firstDayIndex === 0 ? 6 : firstDayIndex - 1;

        let monthNames = ["Leden", "Únor", "Březen", "Duben", "Květen", "Červen", "Červenec", "Srpen", "Září", "Říjen", "Listopad", "Prosinec"];

        let html = `
        <div class="calendar-wrapper">
            <!-- Header Kalendáře (Fixní) -->
            <div class="calendar-header">
                <div class="month-nav">
                    <button onclick="System.changeMonth(-1)"><i class="fas fa-chevron-left"></i></button>
                    <h2>${monthNames[viewMonth]} <span style="font-weight:300; opacity:0.7;">${viewYear}</span></h2>
                    <button onclick="System.changeMonth(1)"><i class="fas fa-chevron-right"></i></button>
                </div>
                
                <div class="today-display" onclick="System.openApp('calendar')"> <!-- Kliknutím reset na dnešek -->
                    <span style="font-size:11px; text-transform:uppercase; opacity:0.6;">Dnes je</span>
                    <span style="font-weight:bold;">${realDate.getDate()}. ${realDate.getMonth() + 1}.</span>
                </div>
            </div>
            
            <!-- Grid Dní (Scrollovací) -->
            <div class="calendar-body">
                <div class="calendar-grid-header">
                    ${['Po','Út','St','Čt','Pá','So','Ne'].map(d => `<div>${d}</div>`).join('')}
                </div>
                
                <div class="calendar-days-grid">
        `;
        
        // Prázdná políčka před prvním dnem
        for(let i = 0; i < czechFirstDayIndex; i++) {
            html += `<div class="day-empty"></div>`;
        }

        // Generování dní
        for(let i = 1; i <= daysInMonth; i++) {
            // Kontrola, zda je tento den "Dnes"
            let isToday = (i === realDate.getDate() && viewMonth === realDate.getMonth() && viewYear === realDate.getFullYear());
            
            // Klíč pro události
            let eventKey = `${i}-${viewMonth + 1}-${viewYear}`;
            let rawData = AppState.calendarEvents[eventKey];
            let hasEvent = (rawData && (typeof rawData === 'string' || rawData.length > 0));

            // Stylování
            let classes = "calendar-day";
            if (isToday) classes += " today";
            if (hasEvent) classes += " has-event";

            // Event indicator
            let indicator = hasEvent ? `<div class="event-dots"></div>` : '';

            html += `
                <div class="${classes}" onclick="System.openCalendarModal(${i}, ${viewMonth + 1}, ${viewYear})">
                    <span class="day-num">${i}</span>
                    ${indicator}
                </div>`;
        }

        html += `
                </div> <!-- End days-grid -->
                
                <!-- Info panel dole -->
                <div class="calendar-footer">
                    <p><i class="fas fa-info-circle"></i> Kliknutím na den naplánujete událost.</p>
                </div>
            </div> <!-- End calendar-body -->
        </div>`; // End wrapper
        
        $('#app-content').html(html);
    },

    openCalendarModal: (day, month, year) => {
        AppState.editingDateKey = `${day}-${month}-${year}`;
        let rawData = AppState.calendarEvents[AppState.editingDateKey];
        
        // Převod starých dat (string) na nové (array), pokud je potřeba
        let events = [];
        if (typeof rawData === 'string') {
            events = [{ time: '--:--', title: rawData }];
        } else if (Array.isArray(rawData)) {
            events = rawData;
        }

        $('#modal-date-title').text(`${day}. ${month}. ${year}`);
        $('#event-title').val('');
        
        // Vyrenderování seznamu
        System.renderEventList(events);

        $('#calendar-modal').css('display', 'flex').hide().fadeIn(200);
    },

    renderEventList: (events) => {
        const list = $('#day-events-list');
        list.empty();

        if (events.length === 0) {
            list.html('<div style="text-align:center; opacity:0.5; padding:20px;">Žádné plány</div>');
            return;
        }

        // Seřadit podle času
        events.sort((a, b) => a.time.localeCompare(b.time));

        events.forEach((ev, index) => {
            list.append(`
                <div class="event-item">
                    <div>
                        <span class="time">${ev.time}</span>
                        <span>${ev.title}</span>
                    </div>
                    <span class="delete-btn" onclick="System.deleteEvent(${index})">&times;</span>
                </div>
            `);
        });
    },

/* html/js/system.js */

    addCalendarEvent: () => {
        let timeInput = $('#event-time');
        let titleInput = $('#event-title');
        
        let time = timeInput.val();
        let title = titleInput.val();

        // Validace
        if (!title || title.trim() === "") return;

        let key = AppState.editingDateKey;
        if (!key) return; // Pojistka

        let rawData = AppState.calendarEvents[key];
        
        // Inicializace pole pokud neexistuje
        let events = Array.isArray(rawData) ? rawData : [];
        
        // Kompatibilita se starými daty (stringem)
        if (typeof rawData === 'string') {
            events = [{time: 'Celý den', title: rawData}];
        }

        events.push({ time: time, title: title });
        
        // Uložení do stavu
        AppState.calendarEvents[key] = events;
        
        // UI aktualizace
        System.renderEventList(events);
        titleInput.val(''); // Vyčistit pole a nechat focus
        titleInput.focus(); 
        
        // Odeslání na server
        System.syncToCloud();
        System.renderCalendar();
    },
    deleteEvent: (index) => {
        let key = AppState.editingDateKey;
        let events = AppState.calendarEvents[key];
        
        if (Array.isArray(events)) {
            events.splice(index, 1);
            if (events.length === 0) delete AppState.calendarEvents[key];
            else AppState.calendarEvents[key] = events;
            
            System.renderEventList(events || []);
            System.syncToCloud();
            System.renderCalendar();
        }
    },


    saveCalendarEvent: () => {
        let val = $('#event-input').val();
        
        if (AppState.editingDateKey) {
            if (val.trim() === "") {
                delete AppState.calendarEvents[AppState.editingDateKey];
            } else {
                AppState.calendarEvents[AppState.editingDateKey] = val;
            }
            
            System.syncToCloud();
            System.renderCalendar(); // Překreslit kalendář s novými daty
            $('#calendar-modal').fadeOut(200);
        }
    },

    // 4. SETTINGS
    renderSettings: () => {
        let storageUsed = (AppState.installedApps.length * 150).toFixed(0); 
        let storageTotal = AppState.currentConfig.storage;
        let percent = Math.min((storageUsed / storageTotal) * 100, 100);
        
        $('#app-content').html(`
        <div style="padding: 40px; height: 100%; box-sizing: border-box;">
            <h1 style="margin-top: 0;">Nastavení</h1>
            
            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Úložiště</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 20px; border-radius: 12px;">
                    <div style="display:flex; justify-content:space-between; margin-bottom: 10px;">
                        <span>Využito</span>
                        <span style="opacity: 0.7;">${storageUsed} MB / ${storageTotal} MB</span>
                    </div>
                    <div style="background: rgba(255,255,255,0.1); height: 8px; border-radius: 4px; overflow:hidden;">
                        <div style="width:${percent}%; background: ${percent > 80 ? '#d63031' : '#0984e3'}; height:100%; transition: width 1s;"></div>
                    </div>
                </div>
            </div>

            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Systém</h3>
                 <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between;">
                        <span>Verze OS</span>
                        <span style="opacity: 0.5;">v2.1 (Beta)</span>
                    </div>
                    <div style="padding: 15px; display:flex; justify-content:space-between;">
                        <span>Sériové číslo</span>
                        <span style="opacity: 0.5; font-family: monospace;">${AppState.currentData.serial || 'N/A'}</span>
                    </div>
                 </div>
            </div>

            <button onclick="System.factoryReset()" style="margin-top:50px; width: 100%; background:rgba(214, 48, 49, 0.2); border:1px solid #d63031; color:#ff7675; padding:12px; border-radius:8px; cursor:pointer; font-weight: bold;">
                Resetovat do továrního nastavení
            </button>
        </div>
        `);
    }
};