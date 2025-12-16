/* html/js/system.js */

const System = {
  Apps: {}, // Kontejner pro interní moduly

  // === REGISTRACE MODULŮ ===
  registerModule: (name, config) => {
    // 1. Uložení logiky modulu
    System.Apps[name] = config;

    // 2. Registrace do seznamu aplikací (pro UI ikony)
    AppState.allRegisteredApps[name] = {
      appName: name,
      label: config.label,
      iconClass: config.icon,
      color: config.color
    };

    // 3. Auto-instalace (pokud už není v DB listu, přidáme ji)
    // Poznámka: Při bootu se toto pole může přepsat daty z DB, 
    // ale systémové appky tam chceme vždy.
    if (!AppState.installedApps.includes(name)) {
      AppState.installedApps.push(name);
    }
  },

  // === BOOT & INIT ===
  boot: (payload) => {
    AppState.currentData = payload;

    // Sloučení nainstalovaných appek z DB a systémových modulů
    let dbApps = payload.installedApps || [];
    // Zajistíme, že systémové moduly jsou vždy "nainstalované"
    Object.keys(System.Apps).forEach(modName => {
        if(!dbApps.includes(modName)) dbApps.push(modName);
    });
    AppState.installedApps = dbApps;

    // Inicializace kalendáře
    AppState.calendarEvents = payload.calendarEvents || {};
    if (Array.isArray(AppState.calendarEvents)) AppState.calendarEvents = {};

    AppState.currentConfig = {
      os: payload.os,
      storage: payload.storage || 1024,
      bootTime: payload.bootTime || 2000,
      wallpaper: payload.wallpaper,
    };

    AppState.activeApp = null;
    UI.showAppFrame(false);
    UI.applyTheme(AppState.currentConfig.os, AppState.currentConfig.wallpaper);
    UI.toggleTablet(true);

    $("#os-content").hide();
    $("#boot-screen").show();

    const bootText = AppState.currentConfig.os === "retro"
        ? `> SYSTEM CHECK... OK\n> MEMORY... OK\n> BOOTING...`
        : '<div class="boot-logo-icon"><i class="fab fa-apple" style="font-size:60px;"></i></div>';

    $("#boot-logo").html(bootText);

    setTimeout(() => {
      $("#boot-screen").fadeOut(300, function () {
        $("#os-content").fadeIn(300);
      });
      UI.renderHomeScreen();
    }, AppState.currentConfig.bootTime);
  },

  // === CORE ===
  openApp: (appName) => {
    // 1. Je to interní modul? (Store, Settings, Calendar)
    if (System.Apps[appName]) {
        AppState.activeApp = appName;
        UI.showAppFrame(true);
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
    $("#app-content").empty();
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
  
  // Pomocná funkce pro bridge mezi JS moduly a Lua
  pluginAction: (appId, actionName, data = {}) => {
    $.post("https://aprts_tablet/appAction", JSON.stringify({
        appId: appId,
        action: actionName,
        data: data,
    }));
  },

  // === API PRO PLUGINY A MODULY ===
  API: {
    renderChart: (payload) => {
      setTimeout(() => {
        const ctx = document.getElementById(payload.targetId);
        if (!ctx) return console.warn(`[Tablet API] Canvas #${payload.targetId} nenalezen.`);

        if (!window.activeCharts) window.activeCharts = {};
        if (window.activeCharts[payload.targetId]) {
          window.activeCharts[payload.targetId].destroy();
          delete window.activeCharts[payload.targetId];
        }

        try {
          if (typeof Chart !== 'undefined') {
              window.activeCharts[payload.targetId] = new Chart(ctx, payload.config);
          } else {
              console.error('[Tablet API] Knihovna Chart.js není načtena!');
          }
        } catch (e) {
          console.error("[Tablet API] Chyba při vytváření grafu:", e);
        }
      }, 150);
    },

    showNotification: (payload) => {
      if (typeof Swal === "undefined") return console.error("SweetAlert2 není načten!");
      Swal.fire({
        title: payload.title,
        text: payload.text,
        icon: payload.icon || "info",
        toast: payload.toast || false,
        position: payload.position || "center",
        timer: payload.timer || 3000,
        showConfirmButton: !payload.toast,
        background: "#1e1e1e",
        color: "#fff",
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
    }
  }
};