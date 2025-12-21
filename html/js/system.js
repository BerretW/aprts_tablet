/* ==========================================================================
   FILE: html/js/system.js
   Popis: Hlavní logika OS tabletu (Boot, Login, App Management, API)
   ========================================================================== */

const System = {
  Apps: {},

  // ==========================================================================
  // 1. AUDIO SYSTÉM
  // ==========================================================================
  playSound: (type) => {
    let audio = document.getElementById("sound-" + type);
    if (audio) {
      audio.currentTime = 0;
      audio.volume = 0.3;
      audio.play().catch((e) => console.log("Audio play blocked", e));
    }
  },

  // ==========================================================================
  // 2. REGISTRACE MODULŮ
  // ==========================================================================
  registerModule: (name, config) => {
    System.Apps[name] = config;
    AppState.allRegisteredApps[name] = {
      appName: name,
      label: config.label,
      iconClass: config.icon,
      color: config.color,
      size: config.size || 20,
      supportedOS: config.supportedOS || 'all'
    };
    if (!AppState.installedApps.includes(name)) {
      AppState.installedApps.push(name);
    }
  },

  // ==========================================================================
  // 3. BOOT & INIT
  // ==========================================================================
  boot: (payload) => {
    AppState.currentData = payload; 

    // Načtení/Init uložených sítí
    AppState.savedNetworks = payload.savedNetworks || {}; 

    let dbApps = payload.installedApps || [];
    Object.keys(System.Apps).forEach((modName) => {
      if (!dbApps.includes(modName)) dbApps.push(modName);
    });
    AppState.installedApps = dbApps;

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
    $("#login-screen").hide();
    $("#boot-screen").show();

    const bootText =
      AppState.currentConfig.os === "retro"
        ? `> SYSTEM CHECK... OK\n> MEMORY... OK\n> SECURITY... ${
            payload.isLocked ? "LOCKED" : "OPEN"
          }\n> BOOTING...`
        : '<div class="boot-logo-icon"><i class="fab fa-apple" style="font-size:60px;"></i></div>';

    $("#boot-logo").html(bootText);

    if (payload.batteryHistory && payload.batteryHistory.length > 0) {
      AppState.batteryHistory = payload.batteryHistory;
    } else {
      AppState.batteryHistory = [{ time: "Teď", value: 100 }];
    }

    setTimeout(() => {
      $("#boot-screen").fadeOut(300, function () {
        if (payload.isLocked) {
          System.Login.init(payload.pin);
        } else {
          $("#os-content").fadeIn(300);
          System.playSound("notify");
        }
      });
      UI.renderHomeScreen();
    }, AppState.currentConfig.bootTime);
  },

  // ==========================================================================
  // 4. LOGIN SYSTÉM
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
        System.playSound("click");
        if (System.Login.currentInput.length === 4) {
          setTimeout(System.Login.verify, 200);
        }
      }
    },

    backspace: () => {
      System.Login.currentInput = System.Login.currentInput.slice(0, -1);
      System.Login.updateDots();
      System.playSound("click");
    },

    updateDots: () => {
      $(".pin-dots .dot").removeClass("active error");
      for (let i = 0; i < System.Login.currentInput.length; i++) {
        $(".pin-dots .dot").eq(i).addClass("active");
      }
    },

    verify: () => {
      if (System.Login.currentInput === System.Login.correctPin) {
        System.playSound("notify");
        $("#login-screen").fadeOut(200, function () {
          $("#os-content").fadeIn(300);
        });
        $.post("https://aprts_tablet/unlockSuccess", JSON.stringify({}));
      } else {
        System.playSound("lock");
        $(".pin-dots .dot").addClass("error");
        System.Login.currentInput = "";
        setTimeout(System.Login.updateDots, 400);
      }
    },
  },

  // ==========================================================================
  // 5. CORE FUNKCE
  // ==========================================================================
  openApp: (appName) => {
    if (System.Apps[appName]) {
      AppState.activeApp = appName;
      UI.showAppFrame(true);
      if (AppState.currentConfig.os === "retro") $(".retro-nav-bar").css("display", "flex");
      System.Apps[appName].render();
      return;
    }
    const app = AppState.allRegisteredApps[appName];
    if (app) {
      AppState.activeApp = appName;
      UI.showAppFrame(true);
      if (AppState.currentConfig.os === "retro") $(".retro-nav-bar").css("display", "flex");
      $.post("https://aprts_tablet/openAppRequest", JSON.stringify({ appId: appName }));
    }
  },

  lockDevice: () => {
    System.playSound("lock");
    $("#os-content").fadeOut(200);
    let currentPin = AppState.currentData.pin || "0000";
    System.Login.init(currentPin);
    $.post("https://aprts_tablet/setLockState", JSON.stringify({ locked: true }));
    AppState.currentData.isLocked = true;
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
      savedNetworks: AppState.savedNetworks
    };
    $.post("https://aprts_tablet/syncData", JSON.stringify(dataToSave));
  },

  pluginAction: (appId, actionName, data = {}) => {
    System.playSound("click");
    $.post("https://aprts_tablet/appAction", JSON.stringify({
        appId: appId,
        action: actionName,
        data: data,
    }));
  },

  // ==========================================================================
  // 6. WIFI PŘIPOJENÍ (OPRAVENO A PŘIDÁNO)
  // ==========================================================================
  connectToProtectedWifi: (ssid) => {
    // 1. Kontrola uloženého hesla
    if (AppState.savedNetworks && AppState.savedNetworks[ssid]) {
       $.post('https://aprts_tablet/connectToWifi', JSON.stringify({
            password: AppState.savedNetworks[ssid]
        }), function(response) {
            if (response.status === 'ok') {
                System.API.showNotification({ title: 'Připojeno', text: `Připojeno k ${ssid}`, icon: 'success', toast: true });
                // Refresh settings pokud je otevřen
                if(AppState.activeApp === 'settings') System.Apps.settings.render();
            } else {
                System.API.showNotification({ title: 'Chyba', text: 'Uložené heslo je nesprávné.', icon: 'error', toast: true });
                delete AppState.savedNetworks[ssid];
                System.connectToProtectedWifi(ssid); // Zkusit znovu ručně
            }
        });
        return; 
    }

    // 2. Dialog pro heslo
    if (typeof Swal !== "undefined") {
      Swal.fire({
        title: `Připojit k síti`,
        text: `Síť "${ssid}" je chráněná heslem.`,
        input: "password",
        inputPlaceholder: "Zadejte heslo",
        showCancelButton: true,
        confirmButtonText: "Připojit",
        cancelButtonText: "Zrušit",
        background: "#1e1e1e",
        color: "#fff",
      }).then((result) => {
        if (result.isConfirmed) {
          const password = result.value;
          $.post("https://aprts_tablet/connectToWifi", JSON.stringify({
              password: password,
          }), function (response) {
              if (response.status === "ok") {
                // Uložit heslo
                if(!AppState.savedNetworks) AppState.savedNetworks = {};
                AppState.savedNetworks[ssid] = password;
                System.syncToCloud();

                System.API.showNotification({
                  title: "Připojeno",
                  text: "Úspěšně připojeno k Wi-Fi.",
                  icon: "success",
                  toast: true,
                });
                
                if(AppState.activeApp === 'settings') System.Apps.settings.render();

              } else {
                System.API.showNotification({
                  title: "Chyba",
                  text: "Nesprávné heslo nebo ztráta signálu.",
                  icon: "error",
                  toast: true,
                });
              }
          });
        }
      });
    } else {
      console.error("SweetAlert2 není načten!");
    }
  },

  // ==========================================================================
  // 7. API PRO PLUGINY
  // ==========================================================================
  API: {
    renderChart: (payload) => {
      setTimeout(() => {
        const ctx = document.getElementById(payload.targetId);
        if (!ctx) return;
        if (!window.activeCharts) window.activeCharts = {};
        if (window.activeCharts[payload.targetId]) {
          window.activeCharts[payload.targetId].destroy();
          delete window.activeCharts[payload.targetId];
        }
        try {
          if (typeof Chart !== "undefined") {
            window.activeCharts[payload.targetId] = new Chart(ctx, payload.config);
          }
        } catch (e) { console.error(e); }
      }, 150);
    },

    showNotification: (payload) => {
      if (typeof Swal === "undefined") return console.error("SweetAlert2 není načten!");
      if (payload.icon === "error") System.playSound("lock");
      else System.playSound("notify");

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
        timerProgressBar: true,
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