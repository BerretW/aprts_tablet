/* html/js/system.js */

const System = {
  // === BOOT & INIT ===
  boot: (payload) => {
    AppState.currentData = payload;

    AppState.installedApps =
      payload.installedApps && payload.installedApps.length > 0
        ? payload.installedApps
        : ["store", "settings", "calendar"];

    // Inicializace kalendáře
    AppState.calendarEvents = payload.calendarEvents || {};
    if (Array.isArray(AppState.calendarEvents)) {
      AppState.calendarEvents = {};
    }

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

    // Reset views
    $("#os-content").hide();
    $("#boot-screen").show();

    // Boot animace
    const bootText =
      AppState.currentConfig.os === "retro"
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
    const app = AppState.allRegisteredApps[appName];
    if (!app) return;

    AppState.activeApp = appName;
    UI.showAppFrame(true);

    if (AppState.currentConfig.os === "retro") {
      $(".retro-nav-bar").css("display", "flex");
    }

    switch (appName) {
      case "store":
        if (!AppState.hasInternet) {
          System.renderNoInternet();
        } else {
          System.renderStore();
        }
        break;
      case "settings":
        System.renderSettings();
        break;
      case "calendar":
        let now = new Date();
        AppState.calendarView = {
          month: now.getMonth(),
          year: now.getFullYear(),
        };
        System.renderCalendar();
        break;
      default:
        $.post(
          "https://aprts_tablet/openAppRequest",
          JSON.stringify({ appId: appName })
        );
        break;
    }
  },

  pluginAction: (appId, actionName, data = {}) => {
    $.post(
      "https://aprts_tablet/appAction",
      JSON.stringify({
        appId: appId,
        action: actionName,
        data: data,
      })
    );
  },

  changeMonth: (direction) => {
    AppState.calendarView.month += direction;
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

  // === APPS ===

  renderNoInternet: () => {
    $("#app-content").html(`
            <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; height:100%; text-align:center;">
                <i class="fas fa-wifi" style="font-size: 64px; margin-bottom: 20px; opacity: 0.3;"></i>
                <h2>Žádné připojení</h2>
                <p style="opacity: 0.6;">Zkontrolujte signál Wi-Fi.</p>
            </div>
        `);
  },

  renderStore: () => {
    let currentNet = $("#network-name").text() || "Neznámá síť";
    let html = `
        <div style="padding: 30px; height: 100%; box-sizing: border-box; display: flex; flex-direction: column;">
            <div style="margin-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 10px;">
                <h1 style="margin: 0; font-size: 32px; font-weight: 700;">App Store</h1>
                <span style="font-size: 13px; opacity: 0.5;"><i class="fas fa-wifi"></i> ${currentNet}</span>
            </div>
            <div style="flex-grow: 1; overflow-y: auto; padding-right: 5px;">
                <div class="store-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
        `;

    Object.keys(AppState.allRegisteredApps).forEach((key) => {
      if (["settings", "calendar"].includes(key)) return;
      let app = AppState.allRegisteredApps[key];
      const isInstalled = AppState.installedApps.includes(key);
      const btnText = isInstalled ? "OTEVŘÍT" : "STÁHNOUT";
      const btnBg = isInstalled ? "rgba(255,255,255,0.1)" : "#0984e3";
      const btnAction = isInstalled
        ? `System.openApp('${key}')`
        : `System.installApp('${key}')`;

      html += `
            <div class="store-card" style="display: flex; align-items: center; justify-content: space-between;">
                <div style="display:flex; align-items:center; gap: 15px;">
                    <div style="background: ${app.color || "#333"}; width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 22px;">
                        <i class="${app.iconClass}" style="color: white;"></i>
                    </div>
                    <div>
                        <div style="font-weight: 600; font-size: 16px;">${app.label}</div>
                        <div style="font-size: 11px; opacity: 0.5;">${isInstalled ? "Nainstalováno" : "Zdarma"}</div>
                    </div>
                </div>
                <button onclick="${btnAction}" style="background: ${btnBg}; color: white; border: none; padding: 8px 18px; border-radius: 20px; font-weight: 700; font-size: 11px; cursor: pointer; transition: 0.2s;">
                    ${btnText}
                </button>
            </div>`;
    });
    html += `</div></div></div>`;
    $("#app-content").html(html);
  },

  installApp: (appName) => {
    if (!AppState.hasInternet) return System.renderNoInternet();
    $("#app-content").html(`
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
      System.renderStore();
    }, 1500);
  },

  // 4. SETTINGS (S TESTOVACÍM GRAFEM)
  renderSettings: () => {
    let storageUsed = (AppState.installedApps.length * 150).toFixed(0);
    let storageTotal = AppState.currentConfig.storage;
    let percent = Math.min((storageUsed / storageTotal) * 100, 100);

    // 1. Vykreslení HTML
    $("#app-content").html(`
        <div style="padding: 40px; height: 100%; box-sizing: border-box; overflow-y: auto;">
            <h1 style="margin-top: 0;">Nastavení</h1>
            
            <!-- ÚLOŽIŠTĚ -->
            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Úložiště</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 20px; border-radius: 12px;">
                    <div style="display:flex; justify-content:space-between; margin-bottom: 10px;">
                        <span>Využito</span>
                        <span style="opacity: 0.7;">${storageUsed} MB / ${storageTotal} MB</span>
                    </div>
                    <div style="background: rgba(255,255,255,0.1); height: 8px; border-radius: 4px; overflow:hidden;">
                        <div style="width:${percent}%; background: ${percent > 80 ? "#d63031" : "#0984e3"}; height:100%; transition: width 1s;"></div>
                    </div>
                </div>
            </div>

            <!-- TEST CHART.JS (DIAGNOSTIKA) -->
            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Diagnostika Výkonu (Chart Test)</h3>
                <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);">
                    <div style="height: 200px; width: 100%;">
                        <canvas id="settingsCpuChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- SYSTÉM INFO -->
            <div style="margin-top: 30px;">
                <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Systém</h3>
                 <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between;">
                        <span>Verze OS</span>
                        <span style="opacity: 0.5;">v2.1 (Beta)</span>
                    </div>
                    <div style="padding: 15px; display:flex; justify-content:space-between;">
                        <span>Sériové číslo</span>
                        <span style="opacity: 0.5; font-family: monospace;">${AppState.currentData.serial || "N/A"}</span>
                    </div>
                 </div>
            </div>

            <button onclick="System.factoryReset()" style="margin-top:50px; margin-bottom: 30px; width: 100%; background:rgba(214, 48, 49, 0.2); border:1px solid #d63031; color:#ff7675; padding:12px; border-radius:8px; cursor:pointer; font-weight: bold;">
                Resetovat do továrního nastavení
            </button>
        </div>
    `);

    // 2. Volání API pro vykreslení grafu (Hned po vložení HTML)
    System.API.renderChart({
        targetId: 'settingsCpuChart',
        config: {
            type: 'line',
            data: {
                labels: ['10s', '8s', '6s', '4s', '2s', 'Teď'],
                datasets: [{
                    label: 'Využití CPU (%)',
                    data: [12, 19, 15, 25, 22, 30],
                    borderColor: '#00b894',
                    backgroundColor: 'rgba(0, 184, 148, 0.2)',
                    borderWidth: 2,
                    tension: 0.4,
                    fill: true,
                    pointRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    x: { ticks: { color: 'rgba(255,255,255,0.5)' }, grid: { display: false } },
                    y: { beginAtZero: true, max: 100, ticks: { color: 'rgba(255,255,255,0.5)' }, grid: { color: 'rgba(255,255,255,0.05)' } }
                },
                animation: { duration: 1500, easing: 'easeOutQuart' }
            }
        }
    });
  },

  renderCalendar: () => {
    let realDate = new Date();
    let viewMonth = AppState.calendarView.month;
    let viewYear = AppState.calendarView.year;
    let daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
    let firstDayIndex = new Date(viewYear, viewMonth, 1).getDay();
    let czechFirstDayIndex = firstDayIndex === 0 ? 6 : firstDayIndex - 1;

    let monthNames = ["Leden", "Únor", "Březen", "Duben", "Květen", "Červen", "Červenec", "Srpen", "Září", "Říjen", "Listopad", "Prosinec"];

    let html = `
        <div class="calendar-wrapper">
            <div class="calendar-header">
                <div class="month-nav">
                    <button onclick="System.changeMonth(-1)"><i class="fas fa-chevron-left"></i></button>
                    <h2>${monthNames[viewMonth]} <span style="font-weight:300; opacity:0.7;">${viewYear}</span></h2>
                    <button onclick="System.changeMonth(1)"><i class="fas fa-chevron-right"></i></button>
                </div>
                <div class="today-display" onclick="System.openApp('calendar')">
                    <span style="font-size:11px; text-transform:uppercase; opacity:0.6;">Dnes je</span>
                    <span style="font-weight:bold;">${realDate.getDate()}. ${realDate.getMonth() + 1}.</span>
                </div>
            </div>
            <div class="calendar-body">
                <div class="calendar-grid-header">
                    ${["Po", "Út", "St", "Čt", "Pá", "So", "Ne"].map((d) => `<div>${d}</div>`).join("")}
                </div>
                <div class="calendar-days-grid">
        `;

    for (let i = 0; i < czechFirstDayIndex; i++) {
      html += `<div class="day-empty"></div>`;
    }

    for (let i = 1; i <= daysInMonth; i++) {
      let isToday = i === realDate.getDate() && viewMonth === realDate.getMonth() && viewYear === realDate.getFullYear();
      let eventKey = `${i}-${viewMonth + 1}-${viewYear}`;
      let rawData = AppState.calendarEvents[eventKey];
      let hasEvent = rawData && (typeof rawData === "string" || rawData.length > 0);
      let classes = "calendar-day";
      if (isToday) classes += " today";
      if (hasEvent) classes += " has-event";
      let indicator = hasEvent ? `<div class="event-dots"></div>` : "";

      html += `
                <div class="${classes}" onclick="System.openCalendarModal(${i}, ${viewMonth + 1}, ${viewYear})">
                    <span class="day-num">${i}</span>
                    ${indicator}
                </div>`;
    }

    html += `</div><div class="calendar-footer"><p><i class="fas fa-info-circle"></i> Kliknutím na den naplánujete událost.</p></div></div></div>`;
    $("#app-content").html(html);
  },

  openCalendarModal: (day, month, year) => {
    AppState.editingDateKey = `${day}-${month}-${year}`;
    let rawData = AppState.calendarEvents[AppState.editingDateKey];
    let events = [];
    if (typeof rawData === "string") {
      events = [{ time: "--:--", title: rawData }];
    } else if (Array.isArray(rawData)) {
      events = rawData;
    }
    $("#modal-date-title").text(`${day}. ${month}. ${year}`);
    $("#event-title").val("");
    System.renderEventList(events);
    $("#calendar-modal").css("display", "flex").hide().fadeIn(200);
  },

  renderEventList: (events) => {
    const list = $("#day-events-list");
    list.empty();
    if (events.length === 0) {
      list.html('<div style="text-align:center; opacity:0.5; padding:20px;">Žádné plány</div>');
      return;
    }
    events.sort((a, b) => a.time.localeCompare(b.time));
    events.forEach((ev, index) => {
      list.append(`
                <div class="event-item">
                    <div><span class="time">${ev.time}</span><span>${ev.title}</span></div>
                    <span class="delete-btn" onclick="System.deleteEvent(${index})">&times;</span>
                </div>
            `);
    });
  },

  addCalendarEvent: () => {
    let timeInput = $("#event-time");
    let titleInput = $("#event-title");
    let time = timeInput.val();
    let title = titleInput.val();
    if (!title || title.trim() === "") return;
    let key = AppState.editingDateKey;
    if (!key) return;
    let rawData = AppState.calendarEvents[key];
    let events = Array.isArray(rawData) ? rawData : [];
    if (typeof rawData === "string") events = [{ time: "Celý den", title: rawData }];
    events.push({ time: time, title: title });
    AppState.calendarEvents[key] = events;
    System.renderEventList(events);
    titleInput.val("").focus();
    System.syncToCloud();
    System.renderCalendar();
  },

  deleteEvent: (index) => {
    Swal.fire({
      title: "Smazat událost?",
      text: "Tuto akci nelze vrátit!",
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#d63031",
      cancelButtonColor: "#333",
      confirmButtonText: "Ano, smazat",
      cancelButtonText: "Zrušit",
      background: "#1e1e1e",
      color: "#fff",
    }).then((result) => {
      if (result.isConfirmed) {
        let key = AppState.editingDateKey;
        let events = AppState.calendarEvents[key];
        if (Array.isArray(events)) {
          events.splice(index, 1);
          if (events.length === 0) delete AppState.calendarEvents[key];
          else AppState.calendarEvents[key] = events;
          System.renderEventList(events || []);
          System.syncToCloud();
          System.renderCalendar();
          Swal.fire({ icon: "success", title: "Smazáno", toast: true, position: "top-end", showConfirmButton: false, timer: 1500, background: "#1e1e1e", color: "#fff" });
        }
      }
    });
  },

  // === API PRO PLUGINY ===
  API: {
    renderChart: (payload) => {
      setTimeout(() => {
        const ctx = document.getElementById(payload.targetId);
        if (!ctx) return console.warn(`[Tablet API] Canvas #${payload.targetId} nenalezen.`);

        // Globální registr grafů pro správný Garbage Collection
        if (!window.activeCharts) window.activeCharts = {};

        // Zničení starého grafu na stejném plátně
        if (window.activeCharts[payload.targetId]) {
          window.activeCharts[payload.targetId].destroy();
          delete window.activeCharts[payload.targetId];
        }

        // Vytvoření nového
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