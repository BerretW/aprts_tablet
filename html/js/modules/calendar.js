System.registerModule('calendar', {
    label: 'Kalendář',
    icon: 'fas fa-calendar-alt',
    color: '#e84393',

    render: function() {
        // Inicializace při prvním otevření
        if(!AppState.calendarView) {
            let now = new Date();
            AppState.calendarView = { month: now.getMonth(), year: now.getFullYear() };
        }

        let realDate = new Date();
        let viewMonth = AppState.calendarView.month;
        let viewYear = AppState.calendarView.year;
        let daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        let firstDayIndex = new Date(viewYear, viewMonth, 1).getDay();
        let czechFirstDayIndex = firstDayIndex === 0 ? 6 : firstDayIndex - 1;

        let monthNames = ["Leden", "Únor", "Březen", "Duben", "Květen", "Červen", "Červenec", "Srpen", "Září", "Říjen", "Listopad", "Prosinec"];

        // Všimni si: System.Apps.calendar.changeMonth(...)
        let html = `
            <div class="calendar-wrapper">
                <div class="calendar-header">
                    <div class="month-nav">
                        <button onclick="System.Apps.calendar.changeMonth(-1)"><i class="fas fa-chevron-left"></i></button>
                        <h2>${monthNames[viewMonth]} <span style="font-weight:300; opacity:0.7;">${viewYear}</span></h2>
                        <button onclick="System.Apps.calendar.changeMonth(1)"><i class="fas fa-chevron-right"></i></button>
                    </div>
                    <div class="today-display" onclick="System.Apps.calendar.resetToToday()">
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

            // Volání System.Apps.calendar.openModal
            html += `
                <div class="${classes}" onclick="System.Apps.calendar.openModal(${i}, ${viewMonth + 1}, ${viewYear})">
                    <span class="day-num">${i}</span>
                    ${indicator}
                </div>`;
        }

        html += `</div><div class="calendar-footer"><p><i class="fas fa-info-circle"></i> Kliknutím na den naplánujete událost.</p></div></div></div>`;
        $("#app-content").html(html);
    },

    // --- LOGIKA MODULU ---

    changeMonth: function(direction) {
        AppState.calendarView.month += direction;
        if (AppState.calendarView.month < 0) {
            AppState.calendarView.month = 11;
            AppState.calendarView.year -= 1;
        } else if (AppState.calendarView.month > 11) {
            AppState.calendarView.month = 0;
            AppState.calendarView.year += 1;
        }
        this.render();
    },

    resetToToday: function() {
        let now = new Date();
        AppState.calendarView = { month: now.getMonth(), year: now.getFullYear() };
        this.render();
    },

    openModal: function(day, month, year) {
        AppState.editingDateKey = `${day}-${month}-${year}`;
        let rawData = AppState.calendarEvents[AppState.editingDateKey];
        let events = [];
        if (typeof rawData === "string") events = [{ time: "--:--", title: rawData }];
        else if (Array.isArray(rawData)) events = rawData;

        $("#modal-date-title").text(`${day}. ${month}. ${year}`);
        $("#event-title").val("");
        
        // Změna: renderEventList voláme z tohoto objektu (this)
        this.renderEventList(events);
        
        // Oprava tlačítka pro přidání v HTML (index.html)
        // V index.html je stále "System.addCalendarEvent()".
        // Protože modal je v index.html staticky, musíme ho dynamicky upravit nebo přepsat onclick.
        // NEJLEPŠÍ ŘEŠENÍ: Přepíšeme onclick atribut tlačítka při otevření modalu:
        $(".new-event-form button").attr("onclick", "System.Apps.calendar.addEvent()");
        
        // Stejně tak input pro enter
        $("#event-title").attr("onkeydown", "if(event.key === 'Enter'){ System.Apps.calendar.addEvent(); event.preventDefault(); }");

        $("#calendar-modal").css("display", "flex").hide().fadeIn(200);
    },

    renderEventList: function(events) {
        const list = $("#day-events-list");
        list.empty();
        if (events.length === 0) {
            list.html('<div style="text-align:center; opacity:0.5; padding:20px;">Žádné plány</div>');
            return;
        }
        events.sort((a, b) => a.time.localeCompare(b.time));
        events.forEach((ev, index) => {
            // Tlačítko smazat: System.Apps.calendar.deleteEvent(...)
            list.append(`
                <div class="event-item">
                    <div><span class="time">${ev.time}</span><span>${ev.title}</span></div>
                    <span class="delete-btn" onclick="System.Apps.calendar.deleteEvent(${index})">&times;</span>
                </div>
            `);
        });
    },

    addEvent: function() {
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
        
        this.renderEventList(events);
        titleInput.val("").focus();
        System.syncToCloud();
        this.render(); // Překreslí kalendář (tečky) na pozadí
    },

    deleteEvent: function(index) {
        Swal.fire({
            title: "Smazat událost?",
            text: "Tuto akci nelze vrátit!",
            icon: "warning",
            showCancelButton: true,
            confirmButtonColor: "#d63031",
            cancelButtonColor: "#333",
            confirmButtonText: "Smazat",
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
                    
                    this.renderEventList(events || []);
                    System.syncToCloud();
                    this.render();
                    
                    Swal.fire({ icon: "success", title: "Smazáno", toast: true, position: "top-end", showConfirmButton: false, timer: 1500, background: "#1e1e1e", color: "#fff" });
                }
            }
        });
    }
});