/* ==========================================================================
   FILE: html/js/ui.js
   Popis: Stará se o vizuální stránku, manipulaci s DOMem a animace.
   ========================================================================== */

const UI = {
    // -------------------------------------------------------------------------
    // 1. ZÁKLADNÍ VIDITELNOST A TÉMATA
    // -------------------------------------------------------------------------

    // Přepnutí viditelnosti celého tabletu (Otevřít/Zavřít)
    toggleTablet: (show) => {
        if (show) {
            $('#tablet-container').fadeIn(250);
        } else {
            $('#tablet-container').fadeOut(250);
        }
    },

    // Aplikování vzhledu (Modern vs Retro)
    applyTheme: (osType, wallpaperUrl) => {
        const root = $('#tablet-os-root');
        
        // Reset tříd a přidání té správné
        root.removeClass('theme-modern theme-retro').addClass('theme-' + osType);

        // Nastavení tapety (pouze pro moderní OS, retro má černé pozadí v CSS)
        const screen = $('.screen');
        if (osType === 'modern' && wallpaperUrl && wallpaperUrl !== 'none') {
            screen.css('background-image', `url(${wallpaperUrl})`);
        } else {
            screen.css('background-image', 'none');
        }
    },

    // -------------------------------------------------------------------------
    // 2. DOMOVSKÁ OBRAZOVKA A IKONY
    // -------------------------------------------------------------------------

    // Vykreslení ikon na domovské obrazovce
    renderHomeScreen: () => {
        const grid = $('#app-grid');
        grid.empty(); // Vyčistíme staré ikony

        // Projdeme nainstalované aplikace ve správném pořadí
        AppState.installedApps.forEach((appName, index) => {
            let app = AppState.allRegisteredApps[appName];
            
            if (app) {
                // Barva pozadí ikony (pokud není definována, dáme tmavou)
                let colorStyle = `background: ${app.color || '#333'}`;
                
                // HTML ikony s atributy pro Drag & Drop
                let html = `
                    <div class="app-icon" draggable="true" data-app="${appName}" data-index="${index}">
                        <div class="icon-wrapper">
                            <i class="${app.iconClass}" style="${colorStyle}"></i>
                        </div>
                        <span>${app.label}</span>
                    </div>`;
                    
                grid.append(html);
            }
        });

        // Po vykreslení aktivujeme Drag & Drop listenery na nových elementech
        UI.enableDragAndDrop();
    },

    // Logika pro přesouvání ikon (Drag & Drop)
    enableDragAndDrop: () => {
        let draggedItem = null;
        const icons = document.querySelectorAll('.app-icon');

        icons.forEach(icon => {
            // 1. Začátek tažení
            icon.addEventListener('dragstart', function(e) {
                draggedItem = this;
                // Malé zpoždění pro CSS efekt "ducha"
                setTimeout(() => this.classList.add('dragging'), 0);
            });

            // 2. Konec tažení
            icon.addEventListener('dragend', function() {
                this.classList.remove('dragging');
                draggedItem = null;
                
                // Po dokončení přeuložíme nové pořadí do databáze
                UI.saveNewIconOrder();
            });

            // 3. Pohyb nad jinou ikonou (Nutné pro povolení dropu)
            icon.addEventListener('dragover', function(e) {
                e.preventDefault(); // Toto povolí drop event
                this.classList.add('drag-over'); // Vizuální efekt rámečku
            });

            // 4. Opuštění prostoru jiné ikony
            icon.addEventListener('dragleave', function() {
                this.classList.remove('drag-over');
            });

            // 5. Puštění (Drop) - Prohození pozic
            icon.addEventListener('drop', function(e) {
                e.preventDefault();
                this.classList.remove('drag-over');

                if (this !== draggedItem) {
                    // Najdeme mřížku
                    const grid = document.getElementById('app-grid');
                    
                    // Získáme pole všech ikon pro porovnání indexů
                    let allIcons = Array.from(document.querySelectorAll('.app-icon'));
                    let indexA = allIcons.indexOf(draggedItem);
                    let indexB = allIcons.indexOf(this);

                    // Manipulace s DOMem (přesunutí elementu na nové místo)
                    if (indexA < indexB) {
                        // Pokud táhneme zleva doprava -> vložíme za cílový element
                        grid.insertBefore(draggedItem, this.nextSibling);
                    } else {
                        // Pokud táhneme zprava doleva -> vložíme před cílový element
                        grid.insertBefore(draggedItem, this);
                    }
                }
            });
        });
    },

    // Uložení nového pořadí ikon
    saveNewIconOrder: () => {
        let newOrder = [];
        // Projdeme aktuální DOM a vytáhneme ID aplikací v novém pořadí
        $('.app-icon').each(function() {
            newOrder.push($(this).data('app'));
        });

        // Aktualizujeme stav aplikace
        AppState.installedApps = newOrder;
        
        // Odešleme změnu na server (uložení do SQL)
        System.syncToCloud();
    },

    // -------------------------------------------------------------------------
    // 3. STATUS BAR (HORNÍ LIŠTA)
    // -------------------------------------------------------------------------

// html/js/ui.js - Najdi funkci updateStatusBar a nahraď ji:

updateStatusBar: (time, hasWifi, wifiName, wifiLevel, battery, isCharging) => {
    // 1. Čas
    $('#clock').text(time);

    // 2. Wi-Fi
    const netNameEl = $('#network-name');
    const wifiIcon = $('.status-bar .fa-signal, .status-bar .fa-wifi, .status-bar .fa-ban');
    
    // Reset ikon
    wifiIcon.removeClass('fa-signal fa-wifi fa-ban text-danger text-warning text-success');

    if (hasWifi) {
        wifiIcon.addClass('fa-wifi');
        
        // Barva podle síly signálu (volitelné)
        if(wifiLevel <= 1) wifiIcon.addClass('text-danger'); // Červená
        else if(wifiLevel <= 2) wifiIcon.addClass('text-warning'); // Žlutá
        else wifiIcon.addClass('text-success'); // Zelená

        // Logika pro text (Název sítě + Volitelná procenta)
        let wifiText = wifiName;
        if (AppState.userSettings.showWifiPct) {
            // Přepočet 0-4 na procenta (přibližně)
            let pct = wifiLevel * 25; 
            wifiText += ` <span style="font-size:11px; opacity:0.8;">(${pct}%)</span>`;
        }
        
        netNameEl.html(wifiText);
    } else {
        wifiIcon.addClass('fa-ban'); 
        netNameEl.text('Žádný signál');
    }

    // 3. Baterie
    // Pokud element neexistuje, vytvoříme ho (vlož to do index.html vedle hodin, nebo to JS udělá samo)
    let batContainer = $('#battery-container');
    if(batContainer.length === 0) {
        $('.status-bar').append('<div id="battery-container" style="display:flex; align-items:center; gap:5px;"></div>');
        batContainer = $('#battery-container');
    }

    // Ikona baterie
    let batIconClass = 'fa-battery-full';
    let batColor = '#fff';

    if(isCharging) {
        batIconClass = 'fa-bolt'; // Blesk při nabíjení
        batColor = '#00b894'; // Zelená
    } else {
        if(battery < 10) { batIconClass = 'fa-battery-empty'; batColor = '#d63031'; }
        else if(battery < 30) { batIconClass = 'fa-battery-quarter'; batColor = '#fab1a0'; }
        else if(battery < 60) { batIconClass = 'fa-battery-half'; }
        else if(battery < 90) { batIconClass = 'fa-battery-three-quarters'; }
    }

    // Vykreslení
    batContainer.html(`
        <span style="font-size:12px; font-weight:600;">${battery}%</span>
        <i class="fas ${batIconClass}" style="color: ${batColor}; ${isCharging ? 'animation: pulse 1.5s infinite;' : ''}"></i>
    `);
},

    // -------------------------------------------------------------------------
    // 4. NAVIGACE (PŘEPÍNÁNÍ OKEN)
    // -------------------------------------------------------------------------

    showAppFrame: (show) => {
        const homeScreen = $('#home-screen');
        const appFrame = $('#app-frame');
        const retroNav = $('.retro-nav-bar');
        const appContent = $('#app-content');

        if (show) {
            // === OTEVÍRÁME APLIKACI ===
            
            // 1. Skryjeme plochu (používáme .hide() pro jistotu spolu s CSS třídou)
            homeScreen.removeClass('active-view').addClass('hidden-view').hide();
            
            // 2. Zobrazíme rám aplikace
            appFrame.removeClass('hidden-view').addClass('active-view').show();

            // 3. Logika pro Retro Navigaci (tlačítko Zpět nahoře)
            if (AppState.currentConfig.os === 'retro') {
                retroNav.css('display', 'flex').removeClass('hidden-view'); 
            } else {
                retroNav.hide(); // Moderní OS lištu nepotřebuje (má gesto/tlačítko dole)
            }

        } else {
            // === JDEME DOMŮ (ZPĚT NA PLOCHU) ===
            
            // 1. Skryjeme aplikaci
            appFrame.removeClass('active-view').addClass('hidden-view').hide();
            
            // 2. Vždy skryjeme retro lištu
            retroNav.hide();
            
            // 3. Zobrazíme plochu
            homeScreen.removeClass('hidden-view').addClass('active-view').show();

            // 4. DŮLEŽITÉ: Vyčistit HTML obsah aplikace
            // Tím zabráníme duplikaci ID elementů a běhu skriptů na pozadí
            appContent.empty();
        }
    },

    // Pomocná funkce pro notifikace (příprava do budoucna)
    showNotification: (title, message) => {
        console.log(`[Tablet Notify] ${title}: ${message}`);
        // Zde by mohl být kód pro zobrazení bubliny nahoře
    }
};