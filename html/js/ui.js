/* ==========================================================================
   FILE: html/js/ui.js
   Popis: Stará se o vizuální stránku, manipulaci s DOMem a animace.
   ========================================================================== */

const UI = {
  // -------------------------------------------------------------------------
  // 1. ZÁKLADNÍ VIDITELNOST A TÉMATA
  // -------------------------------------------------------------------------

  toggleTablet: (show) => {
    if (show) {
      $("#tablet-container").fadeIn(250);
    } else {
      $("#tablet-container").fadeOut(250);
    }
  },

  applyTheme: (osType, wallpaperUrl) => {
    const root = $("#tablet-os-root");
    const themeMapping = {
      retro: "theme-retro",
      kali_os: "theme-kali",
      Apparatus_1: "theme-modern",
      Apparatus_2: "theme-modern",
      android: "theme-modern",
    };

    let visualClass = themeMapping[osType] || "theme-modern";
    root.removeClass("theme-modern theme-retro theme-kali").addClass(visualClass);

    const screen = $(".screen");
    screen.css("background-image", "none"); 

    if (visualClass === "theme-modern" && wallpaperUrl && wallpaperUrl !== "none") {
      screen.css("background-image", `url(${wallpaperUrl})`);
    }
  },

  // -------------------------------------------------------------------------
  // 2. DOMOVSKÁ OBRAZOVKA A IKONY
  // -------------------------------------------------------------------------

  renderHomeScreen: () => {
    const grid = $("#app-grid");
    grid.empty();

    AppState.installedApps.forEach((appName, index) => {
      let app = AppState.allRegisteredApps[appName];
      if (app) {
        let colorStyle = `background: ${app.color || "#333"}`;
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
    UI.enableDragAndDrop();
  },

  enableDragAndDrop: () => {
    let draggedItem = null;
    const icons = document.querySelectorAll(".app-icon");

    icons.forEach((icon) => {
      icon.addEventListener("dragstart", function (e) {
        draggedItem = this;
        setTimeout(() => this.classList.add("dragging"), 0);
      });
      icon.addEventListener("dragend", function () {
        this.classList.remove("dragging");
        draggedItem = null;
        UI.saveNewIconOrder();
      });
      icon.addEventListener("dragover", function (e) {
        e.preventDefault();
        this.classList.add("drag-over");
      });
      icon.addEventListener("dragleave", function () {
        this.classList.remove("drag-over");
      });
      icon.addEventListener("drop", function (e) {
        e.preventDefault();
        this.classList.remove("drag-over");
        if (this !== draggedItem) {
          const grid = document.getElementById("app-grid");
          let allIcons = Array.from(document.querySelectorAll(".app-icon"));
          let indexA = allIcons.indexOf(draggedItem);
          let indexB = allIcons.indexOf(this);
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
    let newOrder = [];
    $(".app-icon").each(function () {
      newOrder.push($(this).data("app"));
    });
    AppState.installedApps = newOrder;
    System.syncToCloud();
  },

  // -------------------------------------------------------------------------
  // 3. STATUS BAR (HORNÍ LIŠTA) - OPRAVENO
  // -------------------------------------------------------------------------

  updateStatusBar: (time, hasWifi, wifiName, wifiLevel, battery, isCharging, wifiLocked) => {
    // 1. Čas
    $("#clock").text(time);

    // 2. Wi-Fi
    const netNameEl = $("#network-name");
    const wifiIcon = $(".status-bar .fa-signal, .status-bar .fa-wifi, .status-bar .fa-ban, .status-bar .fa-lock");

    // Reset ikon a listenerů
    wifiIcon.removeClass("fa-signal fa-wifi fa-ban fa-lock text-danger text-warning text-success animate__animated animate__flash");
    wifiIcon.off("click"); 
    wifiIcon.css("cursor", "default");

    if (hasWifi) {
      // --- PŘIPOJENO ---
      wifiIcon.addClass("fa-wifi");
      
      if (wifiLevel <= 1) wifiIcon.addClass("text-danger");
      else if (wifiLevel <= 2) wifiIcon.addClass("text-warning");
      else wifiIcon.addClass("text-success");

      let wifiText = wifiName;
      if (AppState.userSettings.showWifiPct) {
        let pct = wifiLevel * 25;
        wifiText += ` <span style="font-size:11px; opacity:0.8;">(${pct}%)</span>`;
      }
      netNameEl.html(wifiText);

    } else if (wifiLocked) { 
      // --- ZAMČENO (OPRAVA ZDE: smazáno "data.") ---
      wifiIcon.addClass("fa-lock text-warning");
      wifiIcon.css("cursor", "pointer");
      netNameEl.html(wifiName + " <span style='font-size:10px'>(Zamčeno)</span>");
      
      // Kliknutí vyvolá zadání hesla
      wifiIcon.on("click", function() {
          System.connectToProtectedWifi(wifiName);
      });

    } else {
      // --- ŽÁDNÝ SIGNÁL ---
      wifiIcon.addClass("fa-ban");
      netNameEl.text("Žádný signál");
    }

    // 3. Baterie
    let batContainer = $("#battery-container");
    if (batContainer.length === 0) {
      $(".status-bar").append('<div id="battery-container" style="display:flex; align-items:center; gap:5px;"></div>');
      batContainer = $("#battery-container");
    }

    let batIconClass = "fa-battery-full";
    let batColor = "#fff";

    if (isCharging) {
      batIconClass = "fa-bolt";
      batColor = "#00b894";
    } else {
      if (battery < 10) { batIconClass = "fa-battery-empty"; batColor = "#d63031"; } 
      else if (battery < 30) { batIconClass = "fa-battery-quarter"; batColor = "#fab1a0"; } 
      else if (battery < 60) { batIconClass = "fa-battery-half"; } 
      else if (battery < 90) { batIconClass = "fa-battery-three-quarters"; }
    }

    batContainer.html(`
        <span style="font-size:12px; font-weight:600;">${battery}%</span>
        <i class="fas ${batIconClass}" style="color: ${batColor}; ${isCharging ? "animation: pulse 1.5s infinite;" : ""}"></i>
    `);
  },

  // -------------------------------------------------------------------------
  // 4. NAVIGACE
  // -------------------------------------------------------------------------

  showAppFrame: (show) => {
    const homeScreen = $("#home-screen");
    const appFrame = $("#app-frame");
    const retroNav = $(".retro-nav-bar");
    const appContent = $("#app-content");

    if (show) {
      homeScreen.removeClass("active-view").addClass("hidden-view").hide();
      appFrame.removeClass("hidden-view").addClass("active-view").show();
      if (AppState.currentConfig.os === "retro") {
        retroNav.css("display", "flex").removeClass("hidden-view");
      } else {
        retroNav.hide();
      }
    } else {
      appFrame.removeClass("active-view").addClass("hidden-view").hide();
      retroNav.hide();
      homeScreen.removeClass("hidden-view").addClass("active-view").show();
      appContent.empty();
    }
  },

  showNotification: (title, message) => {
    console.log(`[Tablet Notify] ${title}: ${message}`);
  },
};