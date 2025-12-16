/* ==========================================================================
   FILE: html/js/system.js
   Popis: Hlavní logika OS tabletu (Boot, Login, App Management, API)
   ========================================================================== */

const System = {
    Apps: {}, // Kontejner pro interní moduly (Store, Settings...)

    // ==========================================================================
    // 1. AUDIO SYSTÉM
    // ==========================================================================
    playSound: (type) => {
        // Hledáme element <audio id="sound-type"> v index.html
        let audio = document.getElementById('sound-' + type);
        if (audio) {
            audio.currentTime = 0;
            audio.volume = 0.3; // Hlasitost
            audio.play().catch(e => console.log("Audio play blocked", e));
        }
    },

    // ==========================================================================
    // 2. REGISTRACE MODULŮ
    // ==========================================================================
    registerModule: (name, config) => {
        // 1. Uložení logiky modulu
        System.Apps[name] = config;

        // 2. Registrace do seznamu aplikací (pro UI ikony)
        AppState.allRegisteredApps[name] = {
            appName: name,
            label: config.label,
            iconClass: config.icon,
            color: config.color,
        };

        // 3. Auto-instalace systémových appek
        if (!AppState.installedApps.includes(name)) {
            AppState.installedApps.push(name);
        }
    },

    // ==========================================================================
    // 3. BOOT & INIT (Start systému)
    // ==========================================================================
    boot: (payload) => {
        AppState.currentData = payload; // Uložíme si data ze serveru (vč. PINu a Lock stavu)

        // Sloučení nainstalovaných appek z DB a systémových modulů
        let dbApps = payload.installedApps || [];
        Object.keys(System.Apps).forEach((modName) => {
            if (!dbApps.includes(modName)) dbApps.push(modName);
        });
        AppState.installedApps = dbApps;

        // Inicializace kalendáře
        AppState.calendarEvents = payload.calendarEvents || {};
        if (Array.isArray(AppState.calendarEvents)) AppState.calendarEvents = {};

        // Nastavení Configu
        AppState.currentConfig = {
            os: payload.os,
            storage: payload.storage || 1024,
            bootTime: payload.bootTime || 2000,
            wallpaper: payload.wallpaper,
        };

        // Reset stavu
        AppState.activeApp = null;
        UI.showAppFrame(false);
        UI.applyTheme(AppState.currentConfig.os, AppState.currentConfig.wallpaper);
        UI.toggleTablet(true);

        // Zobrazíme Boot Screen, skryjeme zbytek
        $("#os-content").hide();
        $("#login-screen").hide();
        $("#boot-screen").show();

        // Boot Logo/Text podle OS
        const bootText = AppState.currentConfig.os === "retro"
            ? `> SYSTEM CHECK... OK\n> MEMORY... OK\n> SECURITY... ${payload.isLocked ? "LOCKED" : "OPEN"}\n> BOOTING...`
            : '<div class="boot-logo-icon"><i class="fab fa-apple" style="font-size:60px;"></i></div>';

        $("#boot-logo").html(bootText);

        // Načtení historie baterie
        if (payload.batteryHistory && payload.batteryHistory.length > 0) {
            AppState.batteryHistory = payload.batteryHistory;
        } else {
            AppState.batteryHistory = [{ time: "Teď", value: 100 }];
        }

        // Simulační čas bootování
        setTimeout(() => {
            $("#boot-screen").fadeOut(300, function () {
                // Rozhodování: LOGIN vs PLOCHA
                if (payload.isLocked) {
                    System.Login.init(payload.pin);
                } else {
                    $("#os-content").fadeIn(300);
                    System.playSound('notify'); // Zvuk startu
                }
            });
            UI.renderHomeScreen();
        }, AppState.currentConfig.bootTime);
    },

    // ==========================================================================
    // 4. LOGIN SYSTÉM (PIN)
    // ==========================================================================
    Login: {
        currentInput: "",
        correctPin: "0000",

        init: (pin) => {
            System.Login.correctPin = pin || "0000";
            System.Login.currentInput = "";
            System.Login.updateDots();
            $("#login-screen").fadeIn(200);
        },

        press: (num) => {
            if (System.Login.currentInput.length < 4) {
                System.Login.currentInput += num;
                System.Login.updateDots();
                System.playSound('click'); // Zvuk kliknutí

                if (System.Login.currentInput.length === 4) {
                    setTimeout(System.Login.verify, 200);
                }
            }
        },

        backspace: () => {
            System.Login.currentInput = System.Login.currentInput.slice(0, -1);
            System.Login.updateDots();
            System.playSound('click');
        },

        updateDots: () => {
            $(".pin-dots .dot").removeClass("active error");
            for (let i = 0; i < System.Login.currentInput.length; i++) {
                $(".pin-dots .dot").eq(i).addClass("active");
            }
        },

        verify: () => {
            if (System.Login.currentInput === System.Login.correctPin) {
                // ÚSPĚCH
                System.playSound('notify');
                $("#login-screen").fadeOut(200, function() {
                    $("#os-content").fadeIn(300);
                });
                
                // Odeslat serveru info o odemčení (změna metadat na locked=false)
                $.post('https://aprts_tablet/unlockSuccess', JSON.stringify({}));
            } else {
                // CHYBA
                System.playSound('lock'); // Zvuk chyby
                $(".pin-dots .dot").addClass("error");
                System.Login.currentInput = "";
                setTimeout(System.Login.updateDots, 400);
            }
        }
    },

    // ==========================================================================
    // 5. CORE FUNKCE (Navigace, Sync)
    // ==========================================================================
    openApp: (appName) => {
        // Kontrola oprávnění (Job check - volitelné, pokud implementováno v Lua)
        // Zde jen UI logika:
        
        // 1. Je to interní modul? (Store, Settings, Calendar)
        if (System.Apps[appName]) {
            AppState.activeApp = appName;
            UI.showAppFrame(true);
            
            // Retro navigace
            if (AppState.currentConfig.os === "retro") $(".retro-nav-bar").css("display", "flex");

            // Spustíme render funkci modulu
            System.Apps[appName].render();
            return;
        }

        // 2. Je to externí plugin?
        const app = AppState.allRegisteredApps[appName];
        if (app) {
            AppState.activeApp = appName;
            UI.showAppFrame(true);
            
            if (AppState.currentConfig.os === "retro") $(".retro-nav-bar").css("display", "flex");

            // Voláme Lua event
            $.post("https://aprts_tablet/openAppRequest", JSON.stringify({ appId: appName }));
        }
    },

    goHome: () => {
        AppState.activeApp = null;
        UI.showAppFrame(false);
        $("#app-content").empty(); // Vyčistit obsah aplikace
        $("#calendar-modal").fadeOut(100);
    },

    syncToCloud: () => {
        const dataToSave = {
            installedApps: AppState.installedApps,
            background: AppState.currentConfig.wallpaper,
            calendarEvents: AppState.calendarEvents,
        };
        $.post("https://aprts_tablet/syncData", JSON.stringify(dataToSave));
    },

    // Pomocná funkce pro tlačítka v HTML obsahu pluginů (např. Crypto nákup)
    pluginAction: (appId, actionName, data = {}) => {
        System.playSound('click');
        $.post(
            "https://aprts_tablet/appAction",
            JSON.stringify({
                appId: appId,
                action: actionName,
                data: data,
            })
        );
    },

    // ==========================================================================
    // 6. API PRO PLUGINY (Grafy, Notifikace, Update DOM)
    // ==========================================================================
    API: {
        renderChart: (payload) => {
            setTimeout(() => {
                const ctx = document.getElementById(payload.targetId);
                if (!ctx) return console.warn(`[Tablet API] Canvas #${payload.targetId} nenalezen.`);

                if (!window.activeCharts) window.activeCharts = {};
                // Pokud graf existuje, zničíme ho (refresh)
                if (window.activeCharts[payload.targetId]) {
                    window.activeCharts[payload.targetId].destroy();
                    delete window.activeCharts[payload.targetId];
                }

                try {
                    if (typeof Chart !== "undefined") {
                        window.activeCharts[payload.targetId] = new Chart(ctx, payload.config);
                    } else {
                        console.error("[Tablet API] Knihovna Chart.js není načtena!");
                    }
                } catch (e) {
                    console.error("[Tablet API] Chyba při vytváření grafu:", e);
                }
            }, 150); // Krátký delay pro jistotu, že je DOM ready
        },

        showNotification: (payload) => {
            if (typeof Swal === "undefined") return console.error("SweetAlert2 není načten!");
            
            // Zvuk notifikace
            if(payload.icon === 'error') System.playSound('lock');
            else System.playSound('notify');

            Swal.fire({
                title: payload.title,
                text: payload.text,
                icon: payload.icon || "info",
                toast: payload.toast || false,
                position: payload.position || "top-end",
                timer: payload.timer || 3000,
                showConfirmButton: !payload.toast,
                background: "#1e1e1e",
                color: "#fff",
                timerProgressBar: true
            });
        },

        updateElement: (payload) => {
            const el = $(`#${payload.targetId}`);
            if (el.length) {
                if (payload.isHtml) el.html(payload.content);
                else el.text(payload.content);
                
                if (payload.animate) {
                    el.addClass("animate__animated animate__pulse");
                    setTimeout(() => el.removeClass("animate__animated animate__pulse"), 1000);
                }
            }
        },
    },
};