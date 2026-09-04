// Data for the three Spaces in the Mail for Work prototype.
// (contacts added per Space + global directory)

// Categories used to group Spaces in the sidebar. Order here is display order.
const SPACE_CATEGORIES = ["Marketing", "Sales", "Service", "HR", "Accounting", "Board"];

const SPACES = {
  styrelse: {
    id: "styrelse",
    name: "Styrelsearbete",
    address: "styrelse-acme@m4w.ai",
    category: "HR",
    activeCount: 4,
    goal:
      "Driv styrelsearbete från kallelse till publicerat protokoll med full spårbarhet av beslut.",
    rooms: [
      {
        id: "kallelse",
        name: "Kallelse",
        entity: { kind: "ai", label: "AI · Convocation Agent" },
        subgoal: "Kallelse skickad, OSA insamlat",
        key: "öppnar när OSA ≥ 5 av 7",
        items: [
          { id: "k1", title: "Styrelsemöte 12 dec", meta: "väntar på OSA från 2 av 7", state: "waiting" }
        ]
      },
      {
        id: "agenda",
        name: "Agenda",
        entity: { kind: "mixed", label: "AI + Styrelseordförande" },
        subgoal: "Agenda byggd från inkomna ärenden",
        key: "öppnar när ordförande godkänner",
        items: [
          { id: "a1", title: "Agenda 12 dec", meta: "5 punkter inlämnade, 1 i kö", state: "human" }
        ]
      },
      {
        id: "mote",
        name: "Möte",
        entity: { kind: "human", label: "Människor" },
        subgoal: "Mötet genomfört",
        key: "öppnar när möte = avslutat",
        items: [
          { id: "m1", title: "Styrelsemöte 12 dec", meta: "pågår nu", state: "live" }
        ]
      },
      {
        id: "protokoll",
        name: "Protokoll",
        entity: { kind: "mixed", label: "AI · Minute-keeper + Ordförande" },
        subgoal: "Protokoll utkast godkänt",
        key: "öppnar när ordförande signerat",
        items: [
          { id: "p1", title: "Protokoll 14 nov", meta: "utkast väntar på godkännande", state: "human" }
        ]
      },
      {
        id: "beslutslogg",
        name: "Beslutslogg",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Beslut loggade och spårbara",
        key: "stängd terminalstation",
        items: [
          { id: "b1", title: "12 beslut loggade i år", meta: "senaste: budget 2026", state: "done" }
        ]
      }
    ],
    spaceTabs: [
      { label: "Möten", value: "moten" },
      { label: "Beslut", value: "beslut" }
    ],
    meetings: [
      {
        id: "mote-12dec",
        title: "Styrelsemöte 12 dec 2025",
        date: "12 dec 2025",
        status: "planerat",
        location: "Digitalt · Teams",
        attendees: [
          { name: "Karin Lindqvist", role: "Ordförande", present: null },
          { name: "Erik Wennberg", role: "Ledamot", present: null },
          { name: "Anna Söderberg", role: "Ledamot", present: null },
          { name: "Magnus Holm", role: "Ledamot", present: null },
          { name: "Lars Berg", role: "Ledamot", present: null },
          { name: "Petra Nyström", role: "Ledamot", present: null },
          { name: "Johan Ek", role: "Ledamot", present: null }
        ],
        decisions: []
      },
      {
        id: "mote-14nov",
        title: "Styrelsemöte 14 nov 2025",
        date: "14 nov 2025",
        status: "genomfört",
        location: "Huvudkontoret, Stockholm",
        attendees: [
          { name: "Karin Lindqvist", role: "Ordförande", present: true },
          { name: "Erik Wennberg", role: "Ledamot", present: true },
          { name: "Anna Söderberg", role: "Ledamot", present: true },
          { name: "Magnus Holm", role: "Ledamot", present: true },
          { name: "Lars Berg", role: "Ledamot", present: false },
          { name: "Petra Nyström", role: "Ledamot", present: true },
          { name: "Johan Ek", role: "Ledamot", present: false }
        ],
        decisions: [
          { id: "d-budget26", text: "Budget 2026 fastställd", outcome: "Bifall", votes: "5 för, 0 emot" },
          { id: "d-vd", text: "VD-rekrytering inleds, rekryteringsfirma upphandlas", outcome: "Bifall", votes: "5 för, 0 emot" },
          { id: "d-revisor", text: "Revisorsval: BDO kvarstår till nästa stämma", outcome: "Bifall", votes: "4 för, 1 avstod" }
        ]
      },
      {
        id: "mote-3okt",
        title: "Styrelsemöte 3 okt 2025",
        date: "3 okt 2025",
        status: "genomfört",
        location: "Huvudkontoret, Stockholm",
        attendees: [
          { name: "Karin Lindqvist", role: "Ordförande", present: true },
          { name: "Erik Wennberg", role: "Ledamot", present: true },
          { name: "Anna Söderberg", role: "Ledamot", present: false },
          { name: "Magnus Holm", role: "Ledamot", present: true },
          { name: "Lars Berg", role: "Ledamot", present: true },
          { name: "Petra Nyström", role: "Ledamot", present: true },
          { name: "Johan Ek", role: "Ledamot", present: true }
        ],
        decisions: [
          { id: "d-q3", text: "Q3-rapport godkänd", outcome: "Bifall", votes: "6 för, 0 emot" },
          { id: "d-utdelning", text: "Förslag om extra utdelning bordlagt till december", outcome: "Bordlagt", votes: "—" }
        ]
      }
    ],
    artifacts: [
      { id: "a-prot-14nov", title: "Protokoll — styrelsemöte 14 nov 2025", kind: "PDF", room: "Protokoll", date: "Igår 16:22", status: "signerad", by: "Karin Lindqvist", size: "218 kB" },
      { id: "a-prot-3okt", title: "Protokoll — styrelsemöte 3 okt 2025", kind: "PDF", room: "Protokoll", date: "4 okt 2025", status: "signerad", by: "Karin Lindqvist", size: "204 kB" },
      { id: "a-kallelse-12dec", title: "Kallelse — styrelsemöte 12 dec 2025", kind: "PDF", room: "Kallelse", date: "9 dec 2025", status: "skickad", by: "Convocation Agent", size: "96 kB" },
      { id: "a-agenda-12dec", title: "Agenda — 12 dec 2025", kind: "DOCX", room: "Agenda", date: "10 dec 2025", status: "utkast", by: "Ordförande", size: "42 kB" },
      { id: "a-beslut-2025", title: "Beslutslogg 2025 — export", kind: "CSV", room: "Beslutslogg", date: "1 dec 2025", status: "arkiverad", by: "Minute-keeper", size: "18 kB" }
    ],
    passages: [
      { time: "14:32", text: "Agenda 12 dec passerade från Agenda till Möte" },
      { time: "13:18", text: "Protokoll 14 nov passerade från Möte till Protokoll" },
      { time: "11:04", text: "Beslut 'budget 2026' loggad i Beslutslogg" },
      { time: "09:47", text: "Kallelse 12 dec skickad till 7 mottagare" },
      { time: "Igår 16:22", text: "Styrelsemöte 14 nov passerade från Protokoll till Beslutslogg" },
      { time: "Igår 15:01", text: "Protokoll 14 nov signerat av ordförande" },
      { time: "Igår 10:33", text: "Mailet 'Re: punkter till möte' routades till Agenda" },
      { time: "11 dec 17:55", text: "OSA från Karin Lindqvist registrerad" },
      { time: "11 dec 14:12", text: "OSA från Erik Wennberg registrerad" },
      { time: "10 dec 09:21", text: "Nytt ärende 'Revisorsrapport Q3' skapat i Agenda" }
    ],
    inbox: [
      {
        from: "Karin Lindqvist", fromEmail: "karin.lindqvist@acme.se",
        subject: "OSA — kommer på mötet", date: "Idag 14:32", room: "Kallelse", confidence: "high",
        body: ["Hej,", "Bekräftar att jag kommer på styrelsemötet 12 december. Räkna med mig som vanligt.", "Karin"]
      },
      {
        from: "Erik Wennberg", fromEmail: "erik.wennberg@acme.se",
        subject: "Re: kallelse 12 dec", date: "Idag 11:04", room: "Kallelse", confidence: "high",
        body: ["Hej,", "Tack för kallelsen — jag deltar på mötet den 12:e. Hör av er om ni behöver underlag från mig innan dess.", "Erik"]
      },
      {
        from: "Anna Söderberg", fromEmail: "anna.soderberg@acme.se",
        subject: "Punkt till agendan — rekrytering", date: "Idag 09:18", room: "Agenda", confidence: "high",
        body: ["Hej,", "Vill lägga till en punkt om rekryteringsprocessen för ny VD på agendan till nästa möte. Kan skicka ett kort underlag om det behövs.", "Anna"]
      },
      {
        from: "BDO Revision", fromEmail: "kontakt@bdo.se",
        subject: "Revisorsrapport Q3 — utkast", date: "Igår 17:22", room: "Agenda", confidence: "medium", note: "osäker — bekräfta routing",
        body: ["Hej,", "Bifogar utkast till revisorsrapport för Q3. Hör gärna av er med kommentarer innan vi färdigställer den.", "Vänliga hälsningar, BDO Revision"]
      },
      {
        from: "Magnus Holm", fromEmail: "magnus.holm@acme.se",
        subject: "Tillägg till protokoll 14 nov", date: "Igår 15:48", room: "Protokoll", confidence: "high",
        body: ["Hej,", "En liten komplettering till protokollet från 14 november — jag ville förtydliga min reservation kring punkt 4.", "Magnus"]
      },
      {
        from: "Karin Lindqvist", fromEmail: "karin.lindqvist@acme.se",
        subject: "Re: signering protokoll", date: "11 dec", room: "Protokoll", confidence: "high",
        body: ["Hej,", "Har signerat protokollet från styrelsemötet 14 november. Bra jobbat med sammanställningen.", "Karin"]
      }
    ],
    replayBatch: [
      { from: "Karin Lindqvist", subject: "OSA — kommer på mötet", room: "Kallelse", confidence: 98, key: null },
      { from: "Erik Wennberg", subject: "Re: kallelse 12 dec", room: "Kallelse", confidence: 96, key: "OSA ≥ 5 av 7" },
      { from: "Anna Söderberg", subject: "Punkt till agendan — rekrytering", room: "Agenda", confidence: 92, key: null },
      { from: "BDO Revision", subject: "Revisorsrapport Q3", room: "Agenda", confidence: 71, key: null, uncertain: true },
      { from: "Magnus Holm", subject: "Tillägg till protokoll 14 nov", room: "Protokoll", confidence: 88, key: null },
      { from: "Lars Berg", subject: "Re: nästa möte?", room: "Kallelse", confidence: 64, key: null, uncertain: true },
      { from: "Karin Lindqvist", subject: "Signerat — protokoll 14 nov", room: "Protokoll", confidence: 95, key: "ordförande signerat" },
      { from: "Anna Söderberg", subject: "Förslag stadgeändring", room: "Agenda", confidence: 90, key: null }
    ],
    outbox: {
      queued: [
        {
          from: "Kallelse",
          to: "styrelsen@acme.se",
          subject: "Påminnelse — OSA till möte 12 dec",
          preview: "Hej, vi saknar fortfarande OSA från två styrelseledamöter inför mötet på onsdag…",
          status: "schemalagd till 14:00"
        },
        {
          from: "Protokoll",
          to: "karin.lindqvist@acme.se",
          subject: "Protokoll 14 nov — för signering",
          preview: "Bifogat det justerade protokollet. Tre kommentarer från Magnus är inarbetade…",
          status: "väntar på godkännande"
        },
        {
          from: "Beslutslogg",
          to: "ordforande@acme.se",
          subject: "Veckosammanfattning — 3 nya beslut",
          preview: "Denna vecka loggades följande beslut: (1) budget 2026, (2) revisorsval…",
          status: "skickas om 5 minuter"
        }
      ],
      sent: [
        { from: "Kallelse", to: "styrelsen@acme.se", subject: "Kallelse styrelsemöte 12 dec", time: "10 dec 09:21", passage: "Kallelse → kallelse skickad" },
        { from: "Protokoll", to: "magnus.holm@acme.se", subject: "Utkast protokoll 14 nov — kommentera senast fre", time: "21 nov 16:04", passage: "Möte → Protokoll" },
        { from: "Beslutslogg", to: "alla@acme.se", subject: "Beslut: ny VD-rekrytering inleds", time: "14 nov 19:32", passage: "Protokoll → Beslutslogg" }
      ]
    }
  },

  projekt: {
    id: "projekt",
    name: "Projektuppföljning",
    address: "projekt-skolappen@m4w.ai",
    category: "Service",
    activeCount: 11,
    goal:
      "Håll koll på projektet: fånga beslut, skapa uppgifter med ägare, och följ upp deadlines.",
    rooms: [
      {
        id: "inkorg",
        name: "Inkorg",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Nya mail klassificerade",
        key: "öppnar när typ ≠ okänd",
        items: [
          { id: "i1", title: "8 nya mail att klassificera", meta: "äldsta: 2h", state: "waiting" }
        ]
      },
      {
        id: "beslut",
        name: "Beslut",
        entity: { kind: "mixed", label: "AI + Projektledare" },
        subgoal: "Beslut identifierade och bekräftade",
        key: "öppnar när bekräftat av PL",
        items: [
          { id: "be1", title: "Byte av API-leverantör", meta: "väntar bekräftelse", state: "human" },
          { id: "be2", title: "Skjuta release v0.9 → v1.0", meta: "väntar bekräftelse", state: "human" },
          { id: "be3", title: "Lägg till svenskt språkstöd", meta: "väntar bekräftelse", state: "human" }
        ]
      },
      {
        id: "uppgifter",
        name: "Uppgifter",
        entity: { kind: "mixed", label: "AI + Team" },
        subgoal: "Uppgifter skapade med ägare",
        key: "öppnar när ägare = satt",
        items: [
          { id: "u1", title: "Marcus · kodgranskning fre", meta: "deadline om 2 dagar", state: "running" },
          { id: "u2", title: "Lina · kundavstämning", meta: "deadline om 4 dagar", state: "running" }
        ]
      },
      {
        id: "uppfoljning",
        name: "Uppföljning",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Påminnelser skickade vid avvikelse",
        key: "öppnar när status = klar",
        items: [
          { id: "uf1", title: "Designgranskning v0.8", meta: "1 deadline överskriden", state: "amber" }
        ]
      },
      {
        id: "klart",
        name: "Klart",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Leverans bekräftad av kund",
        key: "stängd terminalstation",
        items: [
          { id: "kl1", title: "Leverans v.51", meta: "bekräftad av kund", state: "done" }
        ]
      }
    ],
    artifacts: [
      { id: "a-status-v50", title: "Statusrapport v.50 — Skolappen", kind: "PDF", room: "Uppföljning", date: "Idag 08:30", status: "skickad", by: "Routing Agent", size: "124 kB" },
      { id: "a-tasks", title: "Uppgiftslista — aktiva ägare & deadlines", kind: "CSV", room: "Uppgifter", date: "Igår 14:02", status: "uppdaterad", by: "Routing Agent", size: "12 kB" },
      { id: "a-beslut-log", title: "Beslutslogg — projektbeslut", kind: "CSV", room: "Beslut", date: "11 dec 2025", status: "arkiverad", by: "Projektledare", size: "9 kB" },
      { id: "a-leverans-v51", title: "Leveranskvitto v.51", kind: "PDF", room: "Klart", date: "8 dec 2025", status: "bekräftad", by: "Skolappen AB", size: "88 kB" }
    ],
    passages: [
      { time: "15:18", text: "Beslut 'API-leverantör' passerade från Inkorg till Beslut" },
      { time: "14:02", text: "Uppgift 'kodgranskning fre' tilldelad Marcus" },
      { time: "11:47", text: "Påminnelse skickad: designgranskning v0.8 försenad" },
      { time: "10:12", text: "Mail 'Re: timeline' routat till Inkorg" },
      { time: "Igår 16:55", text: "Leverans v.51 markerad som klar" }
    ],
    inbox: [
      {
        from: "Skolappen AB", fromEmail: "kontakt@skolappen.se",
        subject: "Re: designgranskning v0.8", date: "Idag 09:52", room: "Uppföljning", confidence: "high",
        body: ["Hej,", "Vi har tittat igenom designgranskningen för v0.8 och har några mindre kommentarer — inget som borde påverka tidsplanen.", "Hälsningar, Skolappen AB"]
      },
      {
        from: "Marcus Nilsson", fromEmail: "marcus@acme.se",
        subject: "Beslut: byte av API-leverantör", date: "Idag 08:15", room: "Beslut", confidence: "high",
        body: ["Hej,", "Vi går vidare med byte av API-leverantör enligt förslaget. Kan ni driva vidare i nästa steg?", "Marcus"]
      },
      {
        from: "Lina Ekström", fromEmail: "lina.ekstrom@acme.se",
        subject: "Klar med kundavstämning", date: "Igår 16:40", room: "Uppgifter", confidence: "high",
        body: ["Hej,", "Kundavstämningen är klar för denna vecka — inga avvikelser att flagga.", "Lina"]
      },
      {
        from: "okänd avsändare", fromEmail: "faktura@leverantor.example",
        subject: "Angående fakturan från förra veckan", date: "Igår 11:05", room: "Inkorg", confidence: "medium", note: "osäker — bekräfta routing",
        body: ["Hej,", "Återkommer angående fakturan vi skickade förra veckan — undrar om ni hann titta på den?", "Mvh"]
      }
    ],
    outbox: { queued: [], sent: [] }
  },

  bokforing: {
    id: "bokforing",
    name: "Bokföring",
    address: "bokforing-acme@m4w.ai",
    category: "Accounting",
    activeCount: 27,
    goal:
      "Ta fakturor från mail, extrahera fält, matcha mot inköpsorder, godkänn avvikelser och exportera till Fortnox.",
    spaceTabs: [
      { label: "Efterlevnad", value: "efterlevnad" },
      { label: "Verifikationer", value: "verifikationer" }
    ],
    compliance: [
      {
        id: "c-handelser",
        title: "Alla affärshändelser bokförda",
        ref: "BFL 4 kap. 1 §",
        status: "uppfyllt",
        desc: "Varje affärshändelse ska bokföras så snart det kan ske.",
        state: "142 av 142 händelser bokförda denna period"
      },
      {
        id: "c-verifikationer",
        title: "Korrekta verifikationer",
        ref: "BFL 5 kap. 6–10 §",
        status: "avvikelse",
        desc: "Varje bokföringspost ska styrkas av en verifikation med rätt innehåll.",
        state: "1 faktura saknar fullständigt verifikat — #2024-117 väntar på godkännande"
      },
      {
        id: "c-lopande",
        title: "Löpande registrering",
        ref: "BFL 5 kap. 1–2 §",
        status: "uppfyllt",
        desc: "Affärshändelser ska registreras löpande och i kronologisk ordning.",
        state: "Registreras dagligen · senast idag 11:08"
      },
      {
        id: "c-sparbarhet",
        title: "Spårbarhet",
        ref: "BFL 5 kap. 1 §",
        status: "uppfyllt",
        desc: "Det ska gå att följa en post från verifikation till bokslut och tillbaka.",
        state: "Varje verifikation länkad till sin Passage — full kedja"
      },
      {
        id: "c-avstamningar",
        title: "Avstämningar",
        ref: "God redovisningssed",
        status: "pagar",
        desc: "Konton stäms av mot externa underlag, t.ex. bank och leverantörsreskontra.",
        state: "Bankavstämning nov klar · december pågår"
      },
      {
        id: "c-arkivering",
        title: "Arkivering i minst sju år",
        ref: "BFL 7 kap. 2 §",
        status: "uppfyllt",
        desc: "Räkenskapsinformation ska bevaras i minst sju år i ursprungligt skick.",
        state: "Allt arkiverat oföränderligt t.o.m. 2032"
      },
      {
        id: "c-bokslut",
        title: "Korrekt bokslut / årsredovisning",
        ref: "BFL 6 kap. · ÅRL",
        status: "pagar",
        desc: "Räkenskapsåret avslutas med ett bokslut upprättat enligt god redovisningssed.",
        state: "Bokslut 2025 förbereds · deadline 30 jun 2026"
      }
    ],
    verifications: [
      { ver: "V-2024-118", date: "Idag", supplier: "Telia AB", amount: "4 200 kr", status: "bokförd", archive: "t.o.m. 2033", trace: "Extraktion → Matchning" },
      { ver: "V-2024-117", date: "Idag", supplier: "AWS", amount: "20 140 kr", status: "avvikelse", archive: "t.o.m. 2033", trace: "Matchning → Godkännande" },
      { ver: "V-2024-116", date: "Igår", supplier: "Klarna for Business", amount: "1 290 kr", status: "exporterad", archive: "t.o.m. 2033", trace: "Export → Fortnox" },
      { ver: "V-2024-115", date: "11 dec 2025", supplier: "Företagshälsan", amount: "8 750 kr", status: "exporterad", archive: "t.o.m. 2032", trace: "Export → Fortnox" },
      { ver: "V-2024-114", date: "8 dec 2025", supplier: "Telia AB", amount: "4 200 kr", status: "exporterad", archive: "t.o.m. 2032", trace: "Export → Fortnox" },
      { ver: "V-2024-113", date: "2 dec 2025", supplier: "Fortum", amount: "3 615 kr", status: "exporterad", archive: "t.o.m. 2032", trace: "Export → Fortnox" }
    ],
    rooms: [
      {
        id: "extraktion",
        name: "Extraktion",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Fält extraherade från faktura",
        key: "öppnar när alla obligatoriska fält ≠ tomt",
        items: [
          { id: "e1", title: "Faktura #2024-118 · Telia", meta: "4 200 kr", state: "running" },
          { id: "e2", title: "Faktura #2024-119 · Företagshälsan", meta: "8 750 kr", state: "running" }
        ]
      },
      {
        id: "matchning",
        name: "Matchning",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Matchad mot inköpsorder/avtal",
        key: "öppnar när match = OK eller avvikelse godkänd",
        items: [
          { id: "ma1", title: "Faktura #2024-117 · AWS", meta: "match OK · 1 avvikelse hittad", state: "amber" }
        ]
      },
      {
        id: "godkannande",
        name: "Godkännande",
        entity: { kind: "human", label: "Ekonomiansvarig" },
        subgoal: "Avvikelser granskade manuellt",
        key: "öppnar när signerad av ek.ansv.",
        items: [
          { id: "g1", title: "Faktura #2024-117 · AWS", meta: "väntar på godkännande", state: "human" }
        ]
      },
      {
        id: "export",
        name: "Export",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Exporterad till Fortnox",
        key: "stängd terminalstation",
        items: [
          { id: "ex1", title: "23 fakturor denna vecka", meta: "senast: #2024-116", state: "done" }
        ]
      }
    ],
    artifacts: [
      { id: "a-sie-nov", title: "SIE-fil — november 2025", kind: "SIE", room: "Export", date: "1 dec 2025", status: "exporterad", by: "Fortnox", size: "62 kB" },
      { id: "a-fortnox-batch", title: "Fortnox-export — 23 verifikationer v.50", kind: "SIE", room: "Export", date: "Igår 17:10", status: "exporterad", by: "Fortnox", size: "48 kB" },
      { id: "a-momsrapport-q4", title: "Momsrapport Q4 2025 — underlag", kind: "PDF", room: "Export", date: "Idag 11:08", status: "utkast", by: "AI", size: "156 kB" },
      { id: "a-avstamning-nov", title: "Bankavstämning november", kind: "PDF", room: "Matchning", date: "30 nov 2025", status: "arkiverad", by: "AI", size: "74 kB" },
      { id: "a-faktura-117", title: "Faktura #2024-117 — AWS", kind: "PDF", room: "Godkännande", date: "Idag", status: "granskas", by: "Ekonomiansvarig", size: "112 kB" }
    ],
    passages: [
      { time: "14:32", text: "Faktura #2024-117 passerade från Matchning till Godkännande" },
      { time: "13:55", text: "Faktura #2024-118 från Telia extraherad" },
      { time: "11:08", text: "Faktura #2024-116 exporterad till Fortnox" }
    ],
    contextMails: [
      { from: "Telia AB", subject: "Faktura 2024-118 · 4 200 kr", date: "Idag 10:04", use: true },
      { from: "Företagshälsan", subject: "Faktura 2024-119 · 8 750 kr", date: "Idag 09:21", use: true },
      { from: "AWS Billing", subject: "Invoice 2024-117 · $1,940.00", date: "Igår 22:50", use: true },
      { from: "Klarna for Business", subject: "Faktura 2024-115 · 1 290 kr", date: "11 dec", use: true },
      { from: "Marcus (CFO)", subject: "Re: ny rutin för avvikelser", date: "10 dec", use: false },
      { from: "Fortnox Support", subject: "Re: API-nyckel förnyad", date: "9 dec", use: false }
    ],
    inbox: [
      {
        from: "Telia AB", fromEmail: "faktura@telia.se",
        subject: "Faktura 2024-118 · 4 200 kr", date: "Idag 10:04", room: "Extraktion", confidence: "high",
        body: ["Hej,", "Bifogat finner ni faktura 2024-118 avseende företagsabonnemang, 4 200 kr. Förfallodatum om 30 dagar.", "Telia Företag"]
      },
      {
        from: "AWS Billing", fromEmail: "billing@aws.example",
        subject: "Invoice 2024-117 · $1,940.00", date: "Idag 09:40", room: "Matchning", confidence: "high",
        body: ["Hello,", "Your invoice 2024-117 for this billing period totals $1,940.00. Payment is due within 14 days.", "AWS Billing"]
      },
      {
        from: "Klarna for Business", fromEmail: "business@klarna.example",
        subject: "Faktura 2024-116 · 1 290 kr", date: "Igår 22:50", room: "Export", confidence: "high",
        body: ["Hej,", "Bifogat finner ni er faktura för Klarna for Business, 1 290 kr. Betalning sker automatiskt via autogiro.", "Klarna for Business"]
      },
      {
        from: "okänd@leverantör.se", fromEmail: "okänd@leverantör.se",
        subject: "Bifogad faktura — se pdf", date: "Igår 14:12", room: "Extraktion", confidence: "medium", note: "osäker — bekräfta routing",
        body: ["Hej,", "Bifogar faktura enligt överenskommelse, se pdf. Hör av er vid frågor.", "Mvh"]
      }
    ],
    outbox: { queued: [], sent: [] }
  },

  fakturering: {
    id: "fakturering",
    name: "Fakturering",
    address: "fakturering-ahlen@m4w.ai",
    category: "Sales",
    activeCount: 3,
    goal:
      "Skicka fakturor till kunder utifrån loggad tid, följ upp betalning, och håll koll på obetalda fakturor.",
    rooms: [
      {
        id: "tidslogg",
        name: "Tidslogg",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Loggad tid sammanställd till fakturaunderlag",
        key: "öppnar när perioden avslutas",
        items: [
          { id: "t1", title: "Konsulttid — vecka 26", meta: "18,5 h loggade", state: "running" }
        ]
      },
      {
        id: "faktureringsrum",
        name: "Fakturering",
        entity: { kind: "mixed", label: "AI + Sara" },
        subgoal: "Faktura skapad och godkänd",
        key: "öppnar när Sara godkänner",
        items: [
          { id: "f1", title: "Faktura · Nordic Retail AB", meta: "12 400 kr · väntar på godkännande", state: "human" }
        ]
      },
      {
        id: "uppfoljning",
        name: "Uppföljning",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Betalning bevakad, påminnelse skickad vid försening",
        key: "öppnar när betald = sant",
        items: [
          { id: "u1", title: "Faktura #118 · Butikskedjan AB", meta: "förfaller om 3 dagar", state: "running" }
        ]
      },
      {
        id: "betald",
        name: "Betald",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Betalning bekräftad och arkiverad",
        key: "stängd terminalstation",
        items: [
          { id: "b1", title: "6 fakturor betalda denna månad", meta: "senast: #117", state: "done" }
        ]
      }
    ],
    artifacts: [
      { id: "a-fakt-117", title: "Faktura #117 — Butikskedjan AB", kind: "PDF", room: "Fakturering", date: "5 dec 2025", status: "skickad", by: "Sara Ahlén", size: "64 kB" },
      { id: "a-fakt-116", title: "Faktura #116 — Nordic Retail AB", kind: "PDF", room: "Fakturering", date: "28 nov 2025", status: "bekräftad", by: "Sara Ahlén", size: "58 kB" },
      { id: "a-tid-v25", title: "Tidsunderlag — vecka 25", kind: "CSV", room: "Tidslogg", date: "22 jun 2026", status: "arkiverad", by: "AI", size: "6 kB" }
    ],
    passages: [
      { time: "09:12", text: "Tidsunderlag vecka 26 passerade från Tidslogg till Fakturering" },
      { time: "Igår 17:40", text: "Faktura #117 passerade från Fakturering till Uppföljning" },
      { time: "5 dec 2025", text: "Faktura #117 skickad till Butikskedjan AB" },
      { time: "28 nov 2025", text: "Betalning för faktura #116 bekräftad" }
    ],
    contextMails: [],
    inbox: [
      {
        from: "Nordic Retail AB", fromEmail: "ekonomi@nordicretail.se",
        subject: "Godkänner tidrapport vecka 26", date: "Idag 08:40", room: "Tidslogg", confidence: "high",
        body: ["Hej Sara,", "Vi godkänner tidrapporten för vecka 26 — 18,5 timmar stämmer med vår logg. Gå vidare med fakturering.", "Hälsningar, Nordic Retail AB"]
      },
      {
        from: "Butikskedjan AB", fromEmail: "ekonomi@butikskedjan.se",
        subject: "Fråga om faktura #117", date: "Igår 13:02", room: "Uppföljning", confidence: "high",
        body: ["Hej Sara,", "Vi undrar över radposten på faktura #117 — kan du specificera vilka dagar som ingår? Vill stämma av innan betalning.", "Mvh, Butikskedjan AB"]
      }
    ],
    replayBatch: [],
    outbox: {
      queued: [
        {
          from: "Fakturering",
          to: "faktura@nordicretail.se",
          subject: "Faktura #118 — konsulttid vecka 26",
          preview: "Hej, bifogat faktura för utfört arbete vecka 26 enligt godkänd tidrapport…",
          status: "väntar på godkännande"
        }
      ],
      sent: [
        { from: "Fakturering", to: "faktura@butikskedjan.se", subject: "Faktura #117", time: "5 dec 09:14", passage: "Fakturering → Uppföljning" }
      ]
    }
  }
};

SPACES.fakturering.contacts = [
  { name: "Sara Ahlén", role: "Enskild firma · Ahlén Konsult", email: "sara@ahlenkonsult.se", group: "intern", rooms: ["Fakturering"] },
  { name: "Nordic Retail AB", role: "Kund", email: "faktura@nordicretail.se", group: "extern", rooms: ["Tidslogg", "Fakturering"] },
  { name: "Butikskedjan AB", role: "Kund", email: "faktura@butikskedjan.se", group: "extern", rooms: ["Uppföljning"] },
  { name: "Faktura-AI", role: "Fakturering & uppföljning", email: "", group: "ai", rooms: ["Tidslogg", "Fakturering", "Uppföljning", "Betald"] }
];

const UNCLASSIFIED_SARA = [
  {
    from: "okänd@gmail.com", fromEmail: "okänd@gmail.com",
    subject: "Fråga om era tjänster", date: "Igår", reason: "matchar inget Space",
    body: ["Hej,", "Såg er sida och undrar om ni tar emot nya kunder just nu? Vad kostar en enklare konsultinsats?", "Mvh"]
  }
];

const UNCLASSIFIED = [
  {
    from: "Linda Forsén", fromEmail: "linda.forsen@example.se",
    subject: "Hej — kan ni hjälpa med en sak?", date: "Idag 12:14", reason: "matchar inget Space",
    body: ["Hej,", "Vet inte riktigt vem jag ska vända mig till, men undrar om ni kan hjälpa till med något som inte riktigt passar in i våra vanliga flöden?", "Linda"]
  },
  {
    from: "newsletter@nordicops.io", fromEmail: "newsletter@nordicops.io",
    subject: "Veckans nyhetsbrev — operations", date: "Igår", reason: "ingen process passar",
    body: ["Hej,", "Här är veckans nyhetsbrev med tips och trender inom operations och processautomation.", "Nordic Ops Newsletter"]
  }
];

/* ---------- Contacts ----------
   Alla inblandade aktörer per Space. group: intern | extern | ai.
   Emails återkommer mellan Spaces (t.ex. Marcus Nilsson) så den globala
   vyn kan slå ihop samma person över flera arbetsflöden. */

SPACES.styrelse.contacts = [
  { name: "Karin Lindqvist", role: "Styrelseordförande", email: "karin.lindqvist@acme.se", group: "intern", rooms: ["Agenda", "Protokoll"] },
  { name: "Erik Wennberg", role: "Styrelseledamot", email: "erik.wennberg@acme.se", group: "intern", rooms: ["Kallelse"] },
  { name: "Anna Söderberg", role: "Styrelseledamot", email: "anna.soderberg@acme.se", group: "intern", rooms: ["Agenda"] },
  { name: "Magnus Holm", role: "Styrelseledamot", email: "magnus.holm@acme.se", group: "intern", rooms: ["Protokoll"] },
  { name: "Lars Berg", role: "Styrelseledamot", email: "lars.berg@acme.se", group: "intern", rooms: ["Möte"] },
  { name: "BDO Revision", role: "Extern revisor", email: "revision@bdo.se", group: "extern", rooms: ["Agenda"] },
  { name: "Convocation Agent", role: "Kallelse & OSA", email: "", group: "ai", rooms: ["Kallelse"] },
  { name: "Minute-keeper", role: "Protokoll & beslutslogg", email: "", group: "ai", rooms: ["Protokoll", "Beslutslogg"] }
];

SPACES.projekt.contacts = [
  { name: "Sofia Ek", role: "Projektledare", email: "sofia.ek@acme.se", group: "intern", rooms: ["Beslut"] },
  { name: "Marcus Nilsson", role: "Utvecklare", email: "marcus@acme.se", group: "intern", rooms: ["Uppgifter"] },
  { name: "Lina Berg", role: "Kundansvarig", email: "lina.berg@acme.se", group: "intern", rooms: ["Uppgifter"] },
  { name: "Skolappen AB", role: "Kund", email: "kontakt@skolappen.se", group: "extern", rooms: ["Klart"] },
  { name: "Routing Agent", role: "Klassificering & uppföljning", email: "", group: "ai", rooms: ["Inkorg", "Uppföljning"] }
];

SPACES.bokforing.contacts = [
  { name: "Marcus Nilsson", role: "Ekonomiansvarig · CFO", email: "marcus@acme.se", group: "intern", rooms: ["Godkännande"] },
  { name: "Telia AB", role: "Leverantör", email: "faktura@telia.se", group: "extern", rooms: ["Extraktion"] },
  { name: "Företagshälsan", role: "Leverantör", email: "faktura@foretagshalsan.se", group: "extern", rooms: ["Extraktion"] },
  { name: "AWS Billing", role: "Leverantör", email: "billing@aws.amazon.com", group: "extern", rooms: ["Matchning"] },
  { name: "Klarna for Business", role: "Leverantör", email: "faktura@klarna.com", group: "extern", rooms: ["Extraktion"] },
  { name: "Fortnox Support", role: "Systemleverantör", email: "support@fortnox.se", group: "extern", rooms: ["Export"] },
  { name: "Extraktions-AI", role: "Fältextraktion & export", email: "", group: "ai", rooms: ["Extraktion", "Matchning", "Export"] }
];

// Merge contacts across Spaces into one global directory.
// Humans/externals merge by email; AI-agenter hålls åtskilda per Space (namn+space).
function buildGlobalContacts(spaces, order) {
  const scope = order || ["styrelse", "projekt", "bokforing"];
  const byKey = new Map();
  scope.forEach((sid) => {
    const sp = spaces[sid];
    if (!sp) return;
    (sp.contacts || []).forEach((c) => {
      const key = c.email ? "e:" + c.email.toLowerCase() : "n:" + sid + ":" + c.name;
      if (!byKey.has(key)) {
        byKey.set(key, {
          name: c.name,
          email: c.email,
          group: c.group,
          roles: new Set([c.role]),
          spaces: []
        });
      }
      const g = byKey.get(key);
      g.roles.add(c.role);
      g.spaces.push({ id: sid, name: sp.name, rooms: c.rooms || [] });
    });
  });
  return Array.from(byKey.values()).map((g) => ({
    name: g.name,
    email: g.email,
    group: g.group,
    roles: Array.from(g.roles),
    spaces: g.spaces
  }));
}

const GLOBAL_CONTACTS = buildGlobalContacts(SPACES);

window.SPACES = SPACES;
window.SPACE_CATEGORIES = SPACE_CATEGORIES;
window.UNCLASSIFIED = UNCLASSIFIED;
window.UNCLASSIFIED_SARA = UNCLASSIFIED_SARA;
window.GLOBAL_CONTACTS = GLOBAL_CONTACTS;
window.buildGlobalContacts = buildGlobalContacts;
