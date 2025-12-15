const System = {
    // === BOOT SEQUENCE ===
    boot: (payload) => {
        // Uložení dat přijatých z LUA (DB + Config)
        AppState.currentData = payload; 
        
        // Pokud v DB nejsou žádné aplikace, dáme tam základ.
        AppState.installedApps = (payload.installedApps && payload.installedApps.length > 0) 
            ? payload.installedApps 
            : ['store', 'settings', 'calendar'];

        // Nastavení konfigurace (OS, Storage atd.)
        AppState.currentConfig = {
            os: payload.os,
            storage: payload.storage || 1024,
            bootTime: payload.bootTime || 2000,
            wallpaper: payload.wallpaper // Tapeta z DB (nebo default z configu)
        };

        // 1. Reset zobrazení (Vždy začít na ploše, zavřít aplikace)
        AppState.activeApp = null;
        $('#app-frame').addClass('hidden-view').removeClass('active-view');
        $('#home-screen').removeClass('hidden-view').addClass('active-view');
        $('.retro-nav-bar').hide(); // Skrýt retro lištu
        $('#app-content').empty();

        // 2. Aplikovat vzhled
        UI.applyTheme(AppState.currentConfig.os, AppState.currentConfig.wallpaper);
        UI.toggleTablet(true);

        // 3. Spustit boot animaci
        $('#os-content').hide();
        $('#boot-screen').show();

        const bootText = AppState.currentConfig.os === 'retro' 
            ? `> BIOS DATE: 01/01/1995<br>> CPU: 66MHz<br>> MEMORY TEST... ${AppState.currentConfig.storage}KB OK<br>> MOUNTING SERIAL: ${payload.serial || 'UNK'}<br>> BOOTING...`
            : '<div class="loader"></div>';
        
        $('#boot-logo').html(bootText);

        // 4. Po uplynutí boot času zobrazit plochu
        setTimeout(() => {
            $('#boot-screen').fadeOut(200);
            $('#os-content').fadeIn(200);
            UI.renderHomeScreen();
        }, AppState.currentConfig.bootTime);
    },

    // === NAVIGACE A SYSTÉM ===

    // Otevření aplikace
    openApp: (appName) => {
        const app = AppState.allRegisteredApps[appName];
        if (!app) return;

        AppState.activeApp = appName;
        UI.showAppFrame(true);

        // SPECIALITA PRO RETRO TABLET:
        // Pokud je OS retro, zobrazíme nahoře lištu pro návrat, 
        // protože retro tablet nemá "Home Button" gesto ani tlačítko dole.
        if (AppState.currentConfig.os === 'retro') {
            $('.retro-nav-bar').css('display', 'flex'); // Zobrazit flexboxem
        }

        // Rozcestník: Je to systémová appka nebo externí resource?
        switch (appName) {
            case 'store':
                System.renderStore();
                break;
            case 'settings':
                System.renderSettings();
                break;
            case 'calendar':
                System.renderCalendar();
                break;
            default:
                // Externí aplikace -> voláme Lua
                $.post('https://aprts_tablet/openAppRequest', JSON.stringify({ appId: appName }));
                break;
        }
    },

    // Návrat na plochu (Voláno tlačítkem Domů nebo Retro lištou)
    goHome: () => {
        AppState.activeApp = null;
        UI.showAppFrame(false); // UI helper přepne visibility
        
        // Skrýt retro navigaci
        $('.retro-nav-bar').hide();
        
        // Vyčistit obsah aplikace, aby neběžel na pozadí
        $('#app-content').html('');
    },

    // Synchronizace dat do databáze (volat při každé změně)
    syncToCloud: () => {
        const dataToSave = {
            installedApps: AppState.installedApps,
            background: AppState.currentConfig.wallpaper
        };

        // Odeslání do LUA -> Server -> MySQL
        $.post('https://aprts_tablet/syncData', JSON.stringify(dataToSave));
    },


    // === INTERNÍ APLIKACE ===

    // 1. APP STORE
    renderStore: () => {
        let html = `<div style="padding:20px"><h2>Software Center</h2><hr>`;
        
        $.each(AppState.allRegisteredApps, function(key, app) {
            // Skryjeme systémové aplikace, ty nejde instalovat/odinstalovat
            if(['store', 'settings', 'calendar'].includes(key)) return;

            const isInstalled = AppState.installedApps.includes(key);
            
            // Styl tlačítka podle stavu
            const btnText = isInstalled ? "Nainstalováno" : "Stáhnout";
            const btnStyle = isInstalled 
                ? "background:#555; color:#ccc; cursor:default;" 
                : "background:#0984e3; color:white; cursor:pointer;";

            html += `
            <div style="margin-bottom: 15px; background: rgba(255,255,255,0.05); padding: 15px; border: 1px solid rgba(255,255,255,0.1); display: flex; justify-content: space-between; align-items: center;">
                <div style="display:flex; align-items:center; gap: 15px;">
                    <i class="${app.iconClass}" style="font-size: 24px; width:30px; text-align:center;"></i> 
                    <div>
                        <div style="font-weight:bold; font-size:16px;">${app.label}</div>
                        <div style="font-size:12px; opacity:0.7;">Verze 1.0</div>
                    </div>
                </div>
                <button onclick="System.installApp('${key}')" style="${btnStyle} border:none; padding:8px 20px; border-radius:4px;" ${isInstalled ? 'disabled' : ''}>
                    ${btnText}
                </button>
            </div>`;
        });
        
        html += `</div>`;
        $('#app-content').html(html);
    },

    installApp: (appName) => {
        if (!AppState.installedApps.includes(appName)) {
            // Simulace stahování
            $('#app-content').html('<div style="display:flex; height:100%; justify-content:center; align-items:center;"><h2>Stahování...</h2></div>');
            
            setTimeout(() => {
                AppState.installedApps.push(appName);
                System.syncToCloud(); // Uložit do DB
                System.renderStore(); // Vrátit se do obchodu
            }, 1000);
        }
    },


    // 2. NASTAVENÍ (SETTINGS)
    renderSettings: () => {
        // Výpočet využití místa (každá appka bere 50MB)
        let storageUsed = AppState.installedApps.length * 50;
        let storageTotal = AppState.currentConfig.storage;
        let percent = Math.min((storageUsed / storageTotal) * 100, 100);
        let barColor = AppState.currentConfig.os === 'retro' ? '#00ff00' : '#0984e3';

        let html = `
        <div style="padding: 40px; max-width: 600px; margin: 0 auto;">
            <h1>Nastavení</h1>
            <hr style="opacity: 0.3; margin: 20px 0;">
            
            <div style="margin-bottom: 30px;">
                <h3>O zařízení</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 8px;">
                    <p><strong>Sériové číslo:</strong> ${AppState.currentData.serial || 'N/A'}</p>
                    <p><strong>Model:</strong> ${AppState.currentConfig.os === 'retro' ? 'RetroPad 95' : 'iFruit Pad Pro'}</p>
                    <p><strong>Operační systém:</strong> ${AppState.currentConfig.os.toUpperCase()}OS v2.4</p>
                </div>
            </div>

            <div style="margin-bottom: 30px;">
                <h3>Úložiště</h3>
                <div style="background: #333; width: 100%; height: 20px; border-radius: 10px; overflow: hidden; margin: 10px 0;">
                    <div style="background: ${barColor}; width: ${percent}%; height: 100%; transition: width 0.5s;"></div>
                </div>
                <div style="display:flex; justify-content:space-between; font-size: 14px; opacity: 0.8;">
                    <span>Využito: ${storageUsed} MB</span>
                    <span>Celkem: ${storageTotal} MB</span>
                </div>
            </div>

            <div style="margin-top: 50px; text-align: center;">
                <button onclick="System.factoryReset()" style="background: #d63031; color: white; border: none; padding: 15px 30px; border-radius: 5px; cursor: pointer; font-size: 16px;">
                    <i class="fas fa-trash"></i> Obnovit tovární nastavení
                </button>
                <p style="font-size: 12px; color: #d63031; margin-top: 10px;">Pozor: Tato akce smaže všechna data a aplikace.</p>
            </div>
        </div>
        `;
        $('#app-content').html(html);
    },

    factoryReset: () => {
        $('#app-content').html('<div style="display:flex; height:100%; justify-content:center; align-items:center; flex-direction:column;"><h2 style="color:red">Formátování disku...</h2><p>Prosím nevypínejte zařízení.</p></div>');
        
        setTimeout(() => {
             // Reset pole aplikací na základ
             AppState.installedApps = ['store', 'settings', 'calendar'];
             
             // Odeslat reset na server
             System.syncToCloud();

             // Re-boot systému pro efekt
             setTimeout(() => {
                System.boot(AppState.currentData);
             }, 1500);
        }, 3000);
    },


    // 3. KALENDÁŘ
    renderCalendar: () => {
        let date = new Date();
        let days = ['Ne', 'Po', 'Út', 'St', 'Čt', 'Pá', 'So'];
        let dayName = days[date.getDay()];
        
        // Barvy pro aktuální den
        let activeBg = AppState.currentConfig.os === 'retro' ? '#00ff00' : '#e84393';
        let activeColor = AppState.currentConfig.os === 'retro' ? 'black' : 'white';

        let html = `
        <div style="padding: 20px; height: 100%; display: flex; flex-direction: column;">
            <div style="text-align: center; margin-bottom: 20px;">
                <h1 style="font-size: 48px; margin: 0;">${date.getDate()}</h1>
                <h3 style="margin: 0; text-transform: uppercase; opacity: 0.7;">${dayName} / ${(date.getMonth() + 1)} / ${date.getFullYear()}</h3>
            </div>
            
            <div style="flex-grow: 1; overflow-y: auto;">
                <div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 10px; padding: 10px;">
                    <!-- Hlavička dnů -->
                    ${days.map(d => `<div style="text-align:center; font-weight:bold;">${d}</div>`).join('')}
                    
                    <!-- Dny v měsíci (zjednodušeně 1-30) -->
        `;
        
        for(let i=1; i<=30; i++) {
            let isToday = (i === date.getDate());
            let bg = isToday ? activeBg : 'rgba(255,255,255,0.05)';
            let col = isToday ? activeColor : 'inherit';
            
            html += `
                <div style="
                    padding: 15px; 
                    background: ${bg}; 
                    color: ${col}; 
                    text-align: center; 
                    border-radius: 8px;
                    border: 1px solid rgba(255,255,255,0.1);
                ">${i}</div>`;
        }

        html += `
                </div>
                <div style="margin-top: 20px; padding: 20px; background: rgba(0,0,0,0.2); border-radius: 10px;">
                    <h4>Dnešní události</h4>
                    <p style="opacity: 0.6;">Žádné naplánované schůzky.</p>
                </div>
            </div>
        </div>`;
        
        $('#app-content').html(html);
    }
};