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

updateStatusBar: (time, hasWifi, wifiName, wifiLevel, battery) => {
    // 1. Čas
    $('#clock').text(time);

    // 2. Wi-Fi
    const signalIcon = $('.status-bar .fa-signal, .status-bar .fa-wifi, .status-bar .fa-ban');
    signalIcon.removeClass('fa-signal fa-wifi fa-ban');

    if (hasWifi) {
        signalIcon.addClass('fa-wifi');
        $('#network-name').html(`${wifiName} <span style="font-size:10px; opacity:0.7;">(${wifiLevel}/4)</span>`); 
    } else {
        signalIcon.addClass('fa-ban'); 
        $('#network-name').text('Odpojeno');
    }

    // 3. Baterie (Pokud ji chceš zobrazit v liště)
    // Přidej do HTML: <span id="battery-status"></span> vedle hodin
    let batIcon = 'fa-battery-full';
    if(battery < 20) batIcon = 'fa-battery-empty';
    else if(battery < 50) batIcon = 'fa-battery-quarter';
    else if(battery < 75) batIcon = 'fa-battery-half';

    // Pokud nemáš element v HTML, můžeš ho dynamicky přidat nebo jen logovat
    // $('#battery-icon').attr('class', 'fas ' + batIcon);
    // $('#battery-percent').text(battery + '%');
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