const UI = {
    // 1. Přepnutí viditelnosti celého tabletu (Otevřít/Zavřít)
    toggleTablet: (show) => {
        if (show) {
            $('#tablet-container').fadeIn(250);
        } else {
            $('#tablet-container').fadeOut(250);
        }
    },

    // 2. Aplikování vzhledu (Modern vs Retro)
    applyTheme: (osType, wallpaperUrl) => {
        const root = $('#tablet-os-root');
        
        // Reset tříd a přidání té správné
        root.removeClass('theme-modern theme-retro').addClass('theme-' + osType);

        // Nastavení tapety (pouze pro moderní, retro má černé pozadí v CSS)
        const screen = $('.screen');
        if (osType === 'modern' && wallpaperUrl && wallpaperUrl !== 'none') {
            screen.css('background-image', `url(${wallpaperUrl})`);
        } else {
            screen.css('background-image', 'none');
        }
    },

    // 3. Vykreslení ikon na domovské obrazovce
    renderHomeScreen: () => {
        $('#app-grid').empty();

        // Projdeme nainstalované aplikace v AppState
        AppState.installedApps.forEach(appName => {
            let app = AppState.allRegisteredApps[appName];
            
            // Pokud aplikace existuje v definici (nebyla smazána z resourcu)
            if (app) {
                // Barva se aplikuje inline, ale retro CSS ji ignoruje (!important)
                let colorStyle = `background: ${app.color || '#333'}`;
                
                let html = `
                    <div class="app-icon" data-app="${appName}">
                        <div class="icon-wrapper">
                            <i class="${app.iconClass}" style="${colorStyle}"></i>
                        </div>
                        <span>${app.label}</span>
                    </div>`;
                    
                $('#app-grid').append(html);
            }
        });
    },

    // 4. Přepínání mezi plochou a oknem aplikace
    showAppFrame: (show) => {
        const homeScreen = $('#home-screen');
        const appFrame = $('#app-frame');
        const retroNav = $('.retro-nav-bar');
        const appContent = $('#app-content');

        if (show) {
            // OTEVÍRÁME APLIKACI
            homeScreen.removeClass('active-view').addClass('hidden-view');
            appFrame.removeClass('hidden-view').addClass('active-view');

            // Logika pro Retro Navigaci (tlačítko Zpět nahoře)
            if (AppState.currentConfig.os === 'retro') {
                retroNav.css('display', 'flex'); 
            } else {
                retroNav.hide(); // Moderní OS lištu nepotřebuje
            }

        } else {
            // JDEME DOMŮ (Zavíráme aplikaci)
            appFrame.removeClass('active-view').addClass('hidden-view');
            homeScreen.removeClass('hidden-view').addClass('active-view');
            
            // Vždy skryjeme retro lištu
            retroNav.hide();

            // Důležité: Vyčistit HTML obsah aplikace, aby neběžel na pozadí
            // a uvolnila se paměť prohlížeče
            appContent.empty();
        }
    },

    // Pomocná funkce pro notifikace uvnitř tabletu (volitelné rozšíření)
    showNotification: (title, message) => {
        // Pokud bys chtěl v budoucnu přidat notifikace nahoře
        console.log(`[Tablet Notify] ${title}: ${message}`);
    }
};