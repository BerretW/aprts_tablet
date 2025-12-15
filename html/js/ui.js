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
        const grid = $('#app-grid');
        grid.empty();

        AppState.installedApps.forEach((appName, index) => {
            let app = AppState.allRegisteredApps[appName];
            
            if (app) {
                let colorStyle = `background: ${app.color || '#333'}`;
                
                // Přidáme atributy draggable="true" a data-index
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

        // Aktivace Drag & Drop listenerů
        UI.enableDragAndDrop();
    },

    // NOVÁ FUNKCE PRO DRAG & DROP LOGIKU
    enableDragAndDrop: () => {
        let draggedItem = null;
        const icons = document.querySelectorAll('.app-icon');

        icons.forEach(icon => {
            // Začátek tažení
            icon.addEventListener('dragstart', function(e) {
                draggedItem = this;
                setTimeout(() => this.classList.add('dragging'), 0);
            });

            // Konec tažení
            icon.addEventListener('dragend', function() {
                this.classList.remove('dragging');
                draggedItem = null;
                
                // Po dokončení přeuložíme pořadí
                UI.saveNewIconOrder();
            });

            // Tažení nad jinou ikonou
            icon.addEventListener('dragover', function(e) {
                e.preventDefault(); // Nutné pro drop
                this.classList.add('drag-over');
            });

            // Opuštění jiné ikony
            icon.addEventListener('dragleave', function() {
                this.classList.remove('drag-over');
            });

            // Puštění (Drop) - Prohození pozic
            icon.addEventListener('drop', function(e) {
                e.preventDefault();
                this.classList.remove('drag-over');

                if (this !== draggedItem) {
                    // Prohodíme HTML elementy v DOMu
                    let allIcons = Array.from(document.querySelectorAll('.app-icon'));
                    let indexA = allIcons.indexOf(draggedItem);
                    let indexB = allIcons.indexOf(this);

                    const grid = document.getElementById('app-grid');
                    
                    // Jednoduché prohození v poli InstalledApps se stane v saveNewIconOrder,
                    // tady jen vizuálně prohodíme DOM elementy
                    if (indexA < indexB) {
                        grid.insertBefore(draggedItem, this.nextSibling);
                    } else {
                        grid.insertBefore(draggedItem, this);
                    }
                }
            });
        });
    },

    saveNewIconOrder: () => {
        // Získáme nové pořadí z DOMu
        let newOrder = [];
        $('.app-icon').each(function() {
            newOrder.push($(this).data('app'));
        });

        // Uložíme do AppState
        AppState.installedApps = newOrder;
        // Odešleme do DB
        System.syncToCloud();
    },
    updateStatusBar: (time, hasWifi, wifiName) => {
        // Aktualizace času
        $('#clock').text(time);

        // Aktualizace ikony signálu
        const signalIcon = $('.status-bar .fa-signal, .status-bar .fa-wifi, .status-bar .fa-ban');
        
        // Odebereme staré třídy
        signalIcon.removeClass('fa-signal fa-wifi fa-ban');

        if (hasWifi) {
            // Máme Wi-Fi
            signalIcon.addClass('fa-wifi');
            $('#network-name').text(wifiName); // Pokud bys chtěl zobrazit název sítě
        } else {
            // Nemáme Wi-Fi -> Zobrazíme "No Signal" nebo 4G (pokud chceš data všude, nech 4G)
            // Zde předpokládáme, že tablet má JEN Wifi. Pokud má i SIM, logika by byla složitější.
            // Uděláme to tak, že bez Wifi = Žádný internet.
            signalIcon.addClass('fa-ban'); // Ikonka přeškrtnutého kruhu
            $('#network-name').text('Odpojeno');
        }
    },

    // 4. Přepínání mezi plochou a oknem aplikace
showAppFrame: (show) => {
    const homeScreen = $('#home-screen');
    const appFrame = $('#app-frame');
    const retroNav = $('.retro-nav-bar');
    const appContent = $('#app-content');

    if (show) {
        // OTEVÍRÁME APLIKACI
        // 1. Nejprve vše skryjeme a odebereme active
        homeScreen.removeClass('active-view').addClass('hidden-view').hide(); // .hide() je jQuery pojistka
        
        // 2. Zobrazíme aplikaci
        appFrame.removeClass('hidden-view').addClass('active-view').show();

        // Retro lišta
        if (AppState.currentConfig.os === 'retro') {
            retroNav.css('display', 'flex').removeClass('hidden-view'); 
        } else {
            retroNav.hide();
        }

    } else {
        // JDEME DOMŮ
        // 1. Skryjeme aplikaci
        appFrame.removeClass('active-view').addClass('hidden-view').hide();
        retroNav.hide();
        
        // 2. Zobrazíme plochu
        homeScreen.removeClass('hidden-view').addClass('active-view').show();

        // Vyčistit obsah
        appContent.empty();
    }
},

    // Pomocná funkce pro notifikace uvnitř tabletu (volitelné rozšíření)
    showNotification: (title, message) => {
        // Pokud bys chtěl v budoucnu přidat notifikace nahoře
        console.log(`[Tablet Notify] ${title}: ${message}`);
    }
};