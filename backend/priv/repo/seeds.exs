# Seeds the Ops domain (the M4W REST API backing the React frontend in
# priv/static/frontend/mail) with the same demo content the prototype's
# spaces-data.js / auth-data.js used to hold client-side.
#
#     mix run priv/repo/seeds.exs

alias M4w.Repo

alias M4w.Ops.{
  Action,
  AgreementRevision,
  Artifact,
  ComplianceCheck,
  Contact,
  Decision,
  FinanceEntry,
  Item,
  Mail,
  Meeting,
  Org,
  OutboxMessage,
  Passage,
  Room,
  Space,
  TaxCheck,
  User,
  UserSpace,
  Verification
}

defmodule Seed.Helpers do
  alias M4w.Repo
  alias M4w.Ops.{Artifact, Contact, Entity, Item, Mail, Passage, Room}

  @now DateTime.utc_now() |> DateTime.truncate(:second)

  def now, do: @now

  def ago(days, hours \\ 0, minutes \\ 0) do
    DateTime.add(@now, -(days * 86_400 + hours * 3_600 + minutes * 60), :second)
  end

  def room!(space, name, position, entity_kind, entity_label, subgoal, key) do
    room =
      Repo.insert!(%Room{
        space_id: space.id,
        name: name,
        position: position,
        subgoal: subgoal,
        key: key
      })

    seed_entities!(room, entity_kind, entity_label)
    room
  end

  defp seed_entities!(room, "mixed", label) do
    seed_entities!(room, "ai", "AI")
    seed_entities!(room, "human", label)
  end

  defp seed_entities!(room, "human", label) do
    entity!(room, %Entity{kind: "human", name: label || "Person"})
  end

  defp seed_entities!(room, _kind, label) do
    entity!(room, %Entity{kind: "ai", agent_type: "claude_code", name: label || "Agent"})
  end

  # Entities are Space-scoped and linked to Rooms through ops_room_entities.
  defp entity!(room, entity) do
    entity = Repo.insert!(%{entity | space_id: room.space_id})
    Repo.insert_all("ops_room_entities", [%{room_id: room.id, entity_id: entity.id}])
    entity
  end

  def item!(room, title, meta, state) do
    Repo.insert!(%Item{room_id: room.id, title: title, meta: meta, state: state})
  end

  def passage!(space, text, at, opts \\ []) do
    Repo.insert!(%Passage{
      space_id: space.id,
      text: text,
      occurred_at: at,
      item_id: Keyword.get(opts, :item) && Keyword.get(opts, :item).id,
      from_room_id: Keyword.get(opts, :from) && Keyword.get(opts, :from).id,
      to_room_id: Keyword.get(opts, :to) && Keyword.get(opts, :to).id
    })
  end

  def artifact!(space, room, title, kind, status, created_by, size, at) do
    Repo.insert!(%Artifact{
      space_id: space.id,
      room_id: room && room.id,
      title: title,
      kind: kind,
      status: status,
      created_by: created_by,
      size: size,
      url: "#",
      occurred_at: at
    })
  end

  def contact!(space, name, role, email, group, rooms) do
    Repo.insert!(%Contact{
      space_id: space.id,
      name: name,
      role: role,
      email: (email && email != "" && email) || nil,
      kind_group: group,
      rooms: rooms
    })
  end

  def mail!(space, room, attrs) do
    Repo.insert!(%Mail{
      space_id: space && space.id,
      room_id: room && room.id,
      from: attrs.from,
      from_email: Map.get(attrs, :from_email),
      subject: attrs.subject,
      body: Map.get(attrs, :body, []),
      occurred_at: attrs.at,
      confidence: Map.get(attrs, :confidence),
      note: Map.get(attrs, :note),
      reason: Map.get(attrs, :reason),
      status: Map.get(attrs, :status, "routed"),
      purpose: Map.get(attrs, :purpose, "inbox"),
      use: Map.get(attrs, :use),
      replay_room_id: Map.get(attrs, :replay_room) && Map.get(attrs, :replay_room).id,
      replay_confidence: Map.get(attrs, :replay_confidence),
      replay_key: Map.get(attrs, :replay_key),
      replay_uncertain: Map.get(attrs, :replay_uncertain, false)
    })
  end
end

# ---------------- Reset ----------------

Repo.delete_all(Mail)
Repo.delete_all(Space)
Repo.delete_all(User)
Repo.delete_all(Org)

# ---------------- Org + Users ----------------

acme = Repo.insert!(%Org{name: "Acme AB"})

karin =
  Repo.insert!(%User{
    org_id: acme.id,
    name: "Karin Lindqvist",
    email: "karin.lindqvist@acme.se",
    role: "Styrelseordförande",
    initials: "KL"
  })

theresia =
  Repo.insert!(%User{
    org_id: acme.id,
    name: "Theresia Lundberg",
    email: "theresia.lundberg@acme.se",
    role: "VD",
    initials: "TL"
  })

marcus =
  Repo.insert!(%User{
    org_id: acme.id,
    name: "Marcus Nilsson",
    email: "marcus@acme.se",
    role: "Ekonomiansvarig · CFO",
    initials: "MN"
  })

sara =
  Repo.insert!(%User{
    org_id: nil,
    name: "Sara Ahlén",
    email: "sara@ahlenkonsult.se",
    role: "Enskild firma",
    initials: "SA"
  })

link! = fn user, space ->
  Repo.insert!(%UserSpace{user_id: user.id, space_id: space.id})
end

# ================== Space: Styrelsearbete ==================

styrelse =
  Repo.insert!(%Space{
    name: "Styrelsearbete",
    address: "styrelse-acme@m4w.ai",
    category: "Board",
    goal:
      "Driv styrelsearbete från kallelse till publicerat protokoll med full spårbarhet av beslut."
  })

link!.(karin, styrelse)
link!.(theresia, styrelse)

r_kallelse =
  Seed.Helpers.room!(
    styrelse,
    "Kallelse",
    0,
    "ai",
    "AI · Convocation Agent",
    "Kallelse skickad, OSA insamlat",
    "öppnar när OSA ≥ 5 av 7"
  )

r_agenda =
  Seed.Helpers.room!(
    styrelse,
    "Agenda",
    1,
    "mixed",
    "AI + Styrelseordförande",
    "Agenda byggd från inkomna ärenden",
    "öppnar när ordförande godkänner"
  )

r_mote =
  Seed.Helpers.room!(
    styrelse,
    "Möte",
    2,
    "human",
    "Människor",
    "Mötet genomfört",
    "öppnar när möte = avslutat"
  )

r_protokoll =
  Seed.Helpers.room!(
    styrelse,
    "Protokoll",
    3,
    "mixed",
    "AI · Minute-keeper + Ordförande",
    "Protokoll utkast godkänt",
    "öppnar när ordförande signerat"
  )

r_beslutslogg =
  Seed.Helpers.room!(
    styrelse,
    "Beslutslogg",
    4,
    "ai",
    "AI",
    "Beslut loggade och spårbara",
    "stängd terminalstation"
  )

it_kallelse =
  Seed.Helpers.item!(r_kallelse, "Styrelsemöte 12 dec", "väntar på OSA från 2 av 7", "waiting")

it_agenda = Seed.Helpers.item!(r_agenda, "Agenda 12 dec", "5 punkter inlämnade, 1 i kö", "human")
it_mote = Seed.Helpers.item!(r_mote, "Styrelsemöte 12 dec", "pågår nu", "live")

it_protokoll =
  Seed.Helpers.item!(r_protokoll, "Protokoll 14 nov", "utkast väntar på godkännande", "human")

_it_beslutslogg =
  Seed.Helpers.item!(r_beslutslogg, "12 beslut loggade i år", "senaste: budget 2026", "done")

# Dagordning (PDF) för kommande styrelsemöte — byggs i Agenda-rummet och bifogas kallelsen.
agenda_12dec =
  Repo.insert!(%Artifact{
    space_id: styrelse.id,
    room_id: r_agenda.id,
    title: "Dagordning styrelsemöte 12 dec 2025",
    kind: "PDF",
    status: "godkänd",
    created_by: "Karin Lindqvist",
    size: "47 kB",
    url: "/frontend/mail/docs/dagordning-styrelsemote-2025-12-12.pdf",
    occurred_at: Seed.Helpers.ago(-1)
  })

Repo.insert!(%Meeting{
  space_id: styrelse.id,
  title: "Styrelsemöte 12 dec 2025",
  occurred_at: Seed.Helpers.ago(-2),
  status: "planerat",
  location: "Digitalt · Teams",
  agenda_id: agenda_12dec.id,
  attendees: [
    %{"name" => "Karin Lindqvist", "role" => "Ordförande", "present" => nil},
    %{"name" => "Erik Wennberg", "role" => "Ledamot", "present" => nil},
    %{"name" => "Anna Söderberg", "role" => "Ledamot", "present" => nil},
    %{"name" => "Magnus Holm", "role" => "Ledamot", "present" => nil},
    %{"name" => "Lars Berg", "role" => "Ledamot", "present" => nil},
    %{"name" => "Petra Nyström", "role" => "Ledamot", "present" => nil},
    %{"name" => "Johan Ek", "role" => "Ledamot", "present" => nil}
  ]
})

mote_14nov =
  Repo.insert!(%Meeting{
    space_id: styrelse.id,
    title: "Styrelsemöte 14 nov 2025",
    occurred_at: Seed.Helpers.ago(29),
    status: "genomfört",
    location: "Huvudkontoret, Stockholm",
    attendees: [
      %{"name" => "Karin Lindqvist", "role" => "Ordförande", "present" => true},
      %{"name" => "Erik Wennberg", "role" => "Ledamot", "present" => true},
      %{"name" => "Anna Söderberg", "role" => "Ledamot", "present" => true},
      %{"name" => "Magnus Holm", "role" => "Ledamot", "present" => true},
      %{"name" => "Lars Berg", "role" => "Ledamot", "present" => false},
      %{"name" => "Petra Nyström", "role" => "Ledamot", "present" => true},
      %{"name" => "Johan Ek", "role" => "Ledamot", "present" => false}
    ]
  })

Repo.insert!(%Decision{
  meeting_id: mote_14nov.id,
  text: "Budget 2026 fastställd",
  outcome: "Bifall",
  votes: "5 för, 0 emot"
})

Repo.insert!(%Decision{
  meeting_id: mote_14nov.id,
  text: "VD-rekrytering inleds, rekryteringsfirma upphandlas",
  outcome: "Bifall",
  votes: "5 för, 0 emot"
})

Repo.insert!(%Decision{
  meeting_id: mote_14nov.id,
  text: "Revisorsval: BDO kvarstår till nästa stämma",
  outcome: "Bifall",
  votes: "4 för, 1 avstod"
})

mote_3okt =
  Repo.insert!(%Meeting{
    space_id: styrelse.id,
    title: "Styrelsemöte 3 okt 2025",
    occurred_at: Seed.Helpers.ago(60),
    status: "genomfört",
    location: "Huvudkontoret, Stockholm",
    attendees: [
      %{"name" => "Karin Lindqvist", "role" => "Ordförande", "present" => true},
      %{"name" => "Erik Wennberg", "role" => "Ledamot", "present" => true},
      %{"name" => "Anna Söderberg", "role" => "Ledamot", "present" => false},
      %{"name" => "Magnus Holm", "role" => "Ledamot", "present" => true},
      %{"name" => "Lars Berg", "role" => "Ledamot", "present" => true},
      %{"name" => "Petra Nyström", "role" => "Ledamot", "present" => true},
      %{"name" => "Johan Ek", "role" => "Ledamot", "present" => true}
    ]
  })

Repo.insert!(%Decision{
  meeting_id: mote_3okt.id,
  text: "Q3-rapport godkänd",
  outcome: "Bifall",
  votes: "6 för, 0 emot"
})

Repo.insert!(%Decision{
  meeting_id: mote_3okt.id,
  text: "Förslag om extra utdelning bordlagt till december",
  outcome: "Bordlagt",
  votes: "—"
})

for {title, assignee, role, due_days, status} <- [
      {"Ta fram rekryteringsunderlag och kravprofil för ny VD", "Karin Lindqvist", "Ordförande",
       -2, "pagar"},
      {"Upphandla rekryteringsfirma — offerter från tre bolag", "Erik Wennberg", "Ledamot", -2,
       "att_gora"},
      {"Skicka in budget 2026 till banken", "Maria Åkesson", "VD", -2, "klar"},
      {"Återkomma med förslag på utdelningsnivå", "Maria Åkesson", "VD", -2, "att_gora"},
      {"Bekräfta revisionsplan med BDO", "Anna Söderberg", "Ledamot", -2, "pagar"}
    ] do
  Repo.insert!(%Action{
    space_id: styrelse.id,
    meeting_id: mote_14nov.id,
    title: title,
    assignee: assignee,
    assignee_role: role,
    due_at: Seed.Helpers.ago(due_days),
    status: status
  })
end

for {title, kind, amount, note, status, meeting} <- [
      {"Budget 2026 — total omslutning", "budget", 48_500_000, "Fastställd ram", "godkand",
       mote_14nov},
      {"Rekryteringsfirma för ny VD", "utgift", 450_000, "Offert från tre bolag", "att_godkanna",
       mote_14nov},
      {"Revisionsarvode BDO", "utgift", 320_000, "Enligt revisionsplan", "godkand", mote_14nov},
      {"Utdelning till aktieägare", "utgift", 5_000_000, "Bordlagd till december", "avslagen",
       mote_3okt},
      {"Försäljning av dotterbolagsandel", "intakt", 2_400_000, "Engångsintäkt Q4", "godkand",
       mote_3okt}
    ] do
  Repo.insert!(%FinanceEntry{
    space_id: styrelse.id,
    meeting_id: meeting.id,
    title: title,
    kind: kind,
    amount: amount,
    note: note,
    status: status
  })
end

# Skattekontroll — valfri punkt på styrelsemötet (styrelsen ansvarar för att skatter är betalda).
for {title, kind, period, amount, due_days, status, note, meeting} <- [
      {"Moms oktober", "moms", "okt 2025", 612_000, 3, "att_betala", "Förfaller 12 dec",
       mote_14nov},
      {"Arbetsgivaravgifter och avdragen skatt", "arbetsgivaravgifter", "okt 2025", 1_480_000, 3,
       "betald", "Betald via skattekontot", mote_14nov},
      {"Preliminärskatt Q3", "preliminarskatt", "Q3 2025", 890_000, -40, "betald", nil, mote_3okt}
    ] do
  Repo.insert!(%TaxCheck{
    space_id: styrelse.id,
    meeting_id: meeting.id,
    title: title,
    kind: kind,
    period: period,
    amount: amount,
    due_at: Seed.Helpers.ago(-due_days),
    status: status,
    note: note
  })
end

# Balans- och resultaträkning exporterade som PDF från ekonomisystemet (inför styrelsemötet).
for {title, kind, amount, note, file, size} <- [
      {"Balansräkning 2025-10-31", "balansrakning", 21_600_000, "Balansomslutning",
       "balansrakning-2025.pdf", "3 kB"},
      {"Resultaträkning jan–okt 2025", "resultatrakning", 3_100_000, "Periodens resultat",
       "resultatrakning-2025.pdf", "3 kB"}
    ] do
  artifact =
    Repo.insert!(%Artifact{
      space_id: styrelse.id,
      room_id: nil,
      title: title,
      kind: "PDF",
      status: "uppladdad",
      created_by: "Ekonomisystemet",
      size: size,
      url: "/frontend/mail/docs/" <> file,
      occurred_at: Seed.Helpers.ago(29)
    })

  Repo.insert!(%FinanceEntry{
    space_id: styrelse.id,
    meeting_id: mote_14nov.id,
    artifact_id: artifact.id,
    title: title,
    kind: kind,
    amount: amount,
    note: note,
    status: "att_godkanna"
  })
end

Seed.Helpers.artifact!(
  styrelse,
  r_protokoll,
  "Protokoll — styrelsemöte 14 nov 2025",
  "PDF",
  "signerad",
  "Karin Lindqvist",
  "218 kB",
  Seed.Helpers.ago(1, 7)
)

Seed.Helpers.artifact!(
  styrelse,
  r_protokoll,
  "Protokoll — styrelsemöte 3 okt 2025",
  "PDF",
  "signerad",
  "Karin Lindqvist",
  "204 kB",
  Seed.Helpers.ago(31)
)

Seed.Helpers.artifact!(
  styrelse,
  r_kallelse,
  "Kallelse — styrelsemöte 12 dec 2025",
  "PDF",
  "skickad",
  "Convocation Agent",
  "96 kB",
  Seed.Helpers.ago(3)
)

Seed.Helpers.artifact!(
  styrelse,
  r_agenda,
  "Agenda — 12 dec 2025",
  "DOCX",
  "utkast",
  "Ordförande",
  "42 kB",
  Seed.Helpers.ago(2)
)

Seed.Helpers.artifact!(
  styrelse,
  r_beslutslogg,
  "Beslutslogg 2025 — export",
  "CSV",
  "arkiverad",
  "Minute-keeper",
  "18 kB",
  Seed.Helpers.ago(11)
)

Seed.Helpers.passage!(
  styrelse,
  "Agenda 12 dec passerade från Agenda till Möte",
  Seed.Helpers.ago(0, 9, 28),
  from: r_agenda,
  to: r_mote,
  item: it_agenda
)

Seed.Helpers.passage!(
  styrelse,
  "Protokoll 14 nov passerade från Möte till Protokoll",
  Seed.Helpers.ago(0, 10, 42),
  from: r_mote,
  to: r_protokoll,
  item: it_protokoll
)

Seed.Helpers.passage!(
  styrelse,
  "Beslut 'budget 2026' loggad i Beslutslogg",
  Seed.Helpers.ago(0, 13, 0)
)

Seed.Helpers.passage!(
  styrelse,
  "Kallelse 12 dec skickad till 7 mottagare",
  Seed.Helpers.ago(0, 14, 13)
)

Seed.Helpers.passage!(
  styrelse,
  "Styrelsemöte 14 nov passerade från Protokoll till Beslutslogg",
  Seed.Helpers.ago(1, 7, 38),
  from: r_protokoll,
  to: r_beslutslogg
)

Seed.Helpers.passage!(
  styrelse,
  "Protokoll 14 nov signerat av ordförande",
  Seed.Helpers.ago(1, 8, 59)
)

Seed.Helpers.passage!(
  styrelse,
  "Mailet 'Re: punkter till möte' routades till Agenda",
  Seed.Helpers.ago(1, 13, 27)
)

Seed.Helpers.passage!(styrelse, "OSA från Karin Lindqvist registrerad", Seed.Helpers.ago(2, 6, 5))
Seed.Helpers.passage!(styrelse, "OSA från Erik Wennberg registrerad", Seed.Helpers.ago(2, 9, 48))

Seed.Helpers.passage!(
  styrelse,
  "Nytt ärende 'Revisorsrapport Q3' skapat i Agenda",
  Seed.Helpers.ago(3, 4, 39)
)

Seed.Helpers.mail!(styrelse, r_kallelse, %{
  from: "Karin Lindqvist",
  from_email: "karin.lindqvist@acme.se",
  subject: "OSA — kommer på mötet",
  at: Seed.Helpers.ago(0, 9, 28),
  confidence: "high",
  body: [
    "Hej,",
    "Bekräftar att jag kommer på styrelsemötet 12 december. Räkna med mig som vanligt.",
    "Karin"
  ]
})

Seed.Helpers.mail!(styrelse, r_kallelse, %{
  from: "Erik Wennberg",
  from_email: "erik.wennberg@acme.se",
  subject: "Re: kallelse 12 dec",
  at: Seed.Helpers.ago(0, 12, 56),
  confidence: "high",
  body: [
    "Hej,",
    "Tack för kallelsen — jag deltar på mötet den 12:e. Hör av er om ni behöver underlag från mig innan dess.",
    "Erik"
  ]
})

Seed.Helpers.mail!(styrelse, r_agenda, %{
  from: "Anna Söderberg",
  from_email: "anna.soderberg@acme.se",
  subject: "Punkt till agendan — rekrytering",
  at: Seed.Helpers.ago(0, 14, 42),
  confidence: "high",
  body: [
    "Hej,",
    "Vill lägga till en punkt om rekryteringsprocessen för ny VD på agendan till nästa möte. Kan skicka ett kort underlag om det behövs.",
    "Anna"
  ]
})

Seed.Helpers.mail!(styrelse, r_agenda, %{
  from: "BDO Revision",
  from_email: "kontakt@bdo.se",
  subject: "Revisorsrapport Q3 — utkast",
  at: Seed.Helpers.ago(1, 6, 38),
  confidence: "medium",
  note: "osäker — bekräfta routing",
  body: [
    "Hej,",
    "Bifogar utkast till revisorsrapport för Q3. Hör gärna av er med kommentarer innan vi färdigställer den.",
    "Vänliga hälsningar, BDO Revision"
  ]
})

Seed.Helpers.mail!(styrelse, r_protokoll, %{
  from: "Magnus Holm",
  from_email: "magnus.holm@acme.se",
  subject: "Tillägg till protokoll 14 nov",
  at: Seed.Helpers.ago(1, 8, 12),
  confidence: "high",
  body: [
    "Hej,",
    "En liten komplettering till protokollet från 14 november — jag ville förtydliga min reservation kring punkt 4.",
    "Magnus"
  ]
})

Seed.Helpers.mail!(styrelse, r_protokoll, %{
  from: "Karin Lindqvist",
  from_email: "karin.lindqvist@acme.se",
  subject: "Re: signering protokoll",
  at: Seed.Helpers.ago(3, 3, 0),
  confidence: "high",
  body: [
    "Hej,",
    "Har signerat protokollet från styrelsemötet 14 november. Bra jobbat med sammanställningen.",
    "Karin"
  ]
})

Seed.Helpers.mail!(styrelse, r_kallelse, %{
  from: "Karin Lindqvist",
  subject: "OSA — kommer på mötet",
  at: Seed.Helpers.ago(4),
  purpose: "replay_candidate",
  replay_room: r_kallelse,
  replay_confidence: 98
})

Seed.Helpers.mail!(styrelse, r_kallelse, %{
  from: "Erik Wennberg",
  subject: "Re: kallelse 12 dec",
  at: Seed.Helpers.ago(4, 1),
  purpose: "replay_candidate",
  replay_room: r_kallelse,
  replay_confidence: 96,
  replay_key: "OSA ≥ 5 av 7"
})

Seed.Helpers.mail!(styrelse, r_agenda, %{
  from: "Anna Söderberg",
  subject: "Punkt till agendan — rekrytering",
  at: Seed.Helpers.ago(4, 2),
  purpose: "replay_candidate",
  replay_room: r_agenda,
  replay_confidence: 92
})

Seed.Helpers.mail!(styrelse, r_agenda, %{
  from: "BDO Revision",
  subject: "Revisorsrapport Q3",
  at: Seed.Helpers.ago(4, 3),
  purpose: "replay_candidate",
  replay_room: r_agenda,
  replay_confidence: 71,
  replay_uncertain: true
})

Seed.Helpers.mail!(styrelse, r_protokoll, %{
  from: "Magnus Holm",
  subject: "Tillägg till protokoll 14 nov",
  at: Seed.Helpers.ago(4, 4),
  purpose: "replay_candidate",
  replay_room: r_protokoll,
  replay_confidence: 88
})

Seed.Helpers.mail!(styrelse, r_kallelse, %{
  from: "Lars Berg",
  subject: "Re: nästa möte?",
  at: Seed.Helpers.ago(4, 5),
  purpose: "replay_candidate",
  replay_room: r_kallelse,
  replay_confidence: 64,
  replay_uncertain: true
})

Seed.Helpers.mail!(styrelse, r_protokoll, %{
  from: "Karin Lindqvist",
  subject: "Signerat — protokoll 14 nov",
  at: Seed.Helpers.ago(4, 6),
  purpose: "replay_candidate",
  replay_room: r_protokoll,
  replay_confidence: 95,
  replay_key: "ordförande signerat"
})

Seed.Helpers.mail!(styrelse, r_agenda, %{
  from: "Anna Söderberg",
  subject: "Förslag stadgeändring",
  at: Seed.Helpers.ago(4, 7),
  purpose: "replay_candidate",
  replay_room: r_agenda,
  replay_confidence: 90
})

Repo.insert!(%OutboxMessage{
  space_id: styrelse.id,
  state: "queued",
  from: "Kallelse",
  to: "styrelsen@acme.se",
  subject: "Påminnelse — OSA till möte 12 dec",
  preview: "Hej, vi saknar fortfarande OSA från två styrelseledamöter inför mötet på onsdag…",
  status_note: "schemalagd till 14:00",
  occurred_at: Seed.Helpers.ago(0)
})

Repo.insert!(%OutboxMessage{
  space_id: styrelse.id,
  state: "queued",
  from: "Protokoll",
  to: "karin.lindqvist@acme.se",
  subject: "Protokoll 14 nov — för signering",
  preview: "Bifogat det justerade protokollet. Tre kommentarer från Magnus är inarbetade…",
  status_note: "väntar på godkännande",
  occurred_at: Seed.Helpers.ago(0)
})

Repo.insert!(%OutboxMessage{
  space_id: styrelse.id,
  state: "queued",
  from: "Beslutslogg",
  to: "ordforande@acme.se",
  subject: "Veckosammanfattning — 3 nya beslut",
  preview: "Denna vecka loggades följande beslut: (1) budget 2026, (2) revisorsval…",
  status_note: "skickas om 5 minuter",
  occurred_at: Seed.Helpers.ago(0)
})

Repo.insert!(%OutboxMessage{
  space_id: styrelse.id,
  state: "sent",
  from: "Kallelse",
  to: "styrelsen@acme.se",
  subject: "Kallelse styrelsemöte 12 dec",
  preview: "",
  passage_note: "Kallelse → kallelse skickad",
  occurred_at: Seed.Helpers.ago(3)
})

Repo.insert!(%OutboxMessage{
  space_id: styrelse.id,
  state: "sent",
  from: "Protokoll",
  to: "magnus.holm@acme.se",
  subject: "Utkast protokoll 14 nov — kommentera senast fre",
  preview: "",
  passage_note: "Möte → Protokoll",
  occurred_at: Seed.Helpers.ago(20)
})

Repo.insert!(%OutboxMessage{
  space_id: styrelse.id,
  state: "sent",
  from: "Beslutslogg",
  to: "alla@acme.se",
  subject: "Beslut: ny VD-rekrytering inleds",
  preview: "",
  passage_note: "Protokoll → Beslutslogg",
  occurred_at: Seed.Helpers.ago(29)
})

Seed.Helpers.contact!(
  styrelse,
  "Karin Lindqvist",
  "Styrelseordförande",
  "karin.lindqvist@acme.se",
  "intern",
  ["Agenda", "Protokoll"]
)

Seed.Helpers.contact!(
  styrelse,
  "Erik Wennberg",
  "Styrelseledamot",
  "erik.wennberg@acme.se",
  "intern",
  ["Kallelse"]
)

Seed.Helpers.contact!(
  styrelse,
  "Anna Söderberg",
  "Styrelseledamot",
  "anna.soderberg@acme.se",
  "intern",
  ["Agenda"]
)

Seed.Helpers.contact!(
  styrelse,
  "Magnus Holm",
  "Styrelseledamot",
  "magnus.holm@acme.se",
  "intern",
  ["Protokoll"]
)

Seed.Helpers.contact!(styrelse, "Lars Berg", "Styrelseledamot", "lars.berg@acme.se", "intern", [
  "Möte"
])

Seed.Helpers.contact!(styrelse, "BDO Revision", "Extern revisor", "revision@bdo.se", "extern", [
  "Agenda"
])

Seed.Helpers.contact!(styrelse, "Convocation Agent", "Kallelse & OSA", nil, "ai", ["Kallelse"])

Seed.Helpers.contact!(styrelse, "Minute-keeper", "Protokoll & beslutslogg", nil, "ai", [
  "Protokoll",
  "Beslutslogg"
])

# ================== Space: Ledningsgrupp ==================

ledning =
  Repo.insert!(%Space{
    name: "Ledningsgrupp",
    address: "ledning-acme@m4w.ai",
    category: "Management",
    goal:
      "Driv ledningsgruppens arbete från agenda och möte till beslut, uppgifter och ekonomisk uppföljning med full spårbarhet."
  })

link!.(theresia, ledning)
link!.(marcus, ledning)

l_agenda =
  Seed.Helpers.room!(
    ledning,
    "Agenda",
    0,
    "mixed",
    "AI + VD",
    "Agenda byggd från ledningsgruppens ärenden",
    "öppnar när VD godkänner"
  )

l_mote =
  Seed.Helpers.room!(
    ledning,
    "Ledningsmöte",
    1,
    "human",
    "Ledningsgruppen",
    "Mötet genomfört",
    "öppnar när möte = avslutat"
  )

l_beslut =
  Seed.Helpers.room!(
    ledning,
    "Beslut",
    2,
    "ai",
    "AI · Minute-keeper",
    "Beslut loggade och spårbara",
    "öppnar när mötesanteckningar är klara"
  )

l_uppgifter =
  Seed.Helpers.room!(
    ledning,
    "Uppgifter",
    3,
    "mixed",
    "AI + Ledningsgrupp",
    "Uppgifter fördelade och uppföljda",
    "öppnar när beslut har ansvarig"
  )

l_ekonomi =
  Seed.Helpers.room!(
    ledning,
    "Ekonomi",
    4,
    "mixed",
    "AI + CFO",
    "Ekonomisk uppföljning godkänd",
    "öppnar när CFO godkänt rapport"
  )

l_it_agenda =
  Seed.Helpers.item!(l_agenda, "Ledningsmöte 20 okt", "4 punkter inlämnade", "human")

_l_it_mote = Seed.Helpers.item!(l_mote, "Ledningsmöte 13 okt", "genomfört", "done")

_l_it_beslut =
  Seed.Helpers.item!(l_beslut, "6 beslut loggade i år", "senaste: budgetram Q4", "done")

_l_it_uppg = Seed.Helpers.item!(l_uppgifter, "7 öppna uppgifter", "2 försenade", "waiting")
_l_it_ekonomi = Seed.Helpers.item!(l_ekonomi, "Månadsrapport september", "väntar på CFO", "human")

l_attendees = fn present ->
  [
    %{"name" => "Theresia Lundberg", "role" => "VD", "present" => present},
    %{"name" => "Marcus Nilsson", "role" => "CFO", "present" => present},
    %{"name" => "Johanna Persson", "role" => "COO", "present" => present},
    %{"name" => "Henrik Sandberg", "role" => "CTO", "present" => present},
    %{"name" => "Emma Falk", "role" => "HR-chef", "present" => present}
  ]
end

l_agenda_doc =
  Repo.insert!(%Artifact{
    space_id: ledning.id,
    room_id: l_agenda.id,
    title: "Dagordning ledningsmöte 20 okt",
    kind: "DOCX",
    status: "utkast",
    created_by: "Theresia Lundberg",
    size: "38 kB",
    url: "#",
    occurred_at: Seed.Helpers.ago(0, 3)
  })

Repo.insert!(%Meeting{
  space_id: ledning.id,
  title: "Ledningsmöte 20 okt",
  occurred_at: Seed.Helpers.ago(-9),
  status: "planerat",
  location: "Huvudkontoret, Stockholm",
  agenda_id: l_agenda_doc.id,
  attendees: l_attendees.(nil)
})

l_mote_13okt =
  Repo.insert!(%Meeting{
    space_id: ledning.id,
    title: "Ledningsmöte 13 okt",
    occurred_at: Seed.Helpers.ago(2),
    status: "genomfört",
    location: "Digitalt · Teams",
    attendees: l_attendees.(true)
  })

l_mote_29sep =
  Repo.insert!(%Meeting{
    space_id: ledning.id,
    title: "Ledningsmöte 29 sep",
    occurred_at: Seed.Helpers.ago(16),
    status: "genomfört",
    location: "Huvudkontoret, Stockholm",
    attendees:
      Enum.map(l_attendees.(true), fn a ->
        if a["name"] == "Emma Falk", do: %{a | "present" => false}, else: a
      end)
  })

for {meeting, text, outcome, votes} <- [
      {l_mote_13okt, "Budgetram Q4 fastställd", "Bifall", "5 för, 0 emot"},
      {l_mote_13okt, "Rekrytering av två utvecklare godkänd", "Bifall", "4 för, 1 avstod"},
      {l_mote_29sep, "Ny prismodell införs 1 jan", "Bifall", "5 för, 0 emot"},
      {l_mote_29sep, "Kontorsflytt skjuts till våren", "Bordlagt", "—"}
    ] do
  Repo.insert!(%Decision{meeting_id: meeting.id, text: text, outcome: outcome, votes: votes})
end

for {title, assignee, role, due_days, status, meeting} <- [
      {"Ta fram rekryteringsannonser för utvecklartjänster", "Emma Falk", "HR-chef", -7, "pagar",
       l_mote_13okt},
      {"Uppdatera prislistor inför ny prismodell", "Johanna Persson", "COO", -5, "att_gora",
       l_mote_13okt},
      {"Teknisk riskanalys inför Q4", "Henrik Sandberg", "CTO", -10, "att_gora", l_mote_13okt},
      {"Kommunicera ny prismodell till kunder", "Theresia Lundberg", "VD", 3, "klar",
       l_mote_29sep},
      {"Utred lokalalternativ inför flytt", "Johanna Persson", "COO", 5, "pagar", l_mote_29sep}
    ] do
  Repo.insert!(%Action{
    space_id: ledning.id,
    meeting_id: meeting.id,
    title: title,
    assignee: assignee,
    assignee_role: role,
    due_at: Seed.Helpers.ago(due_days),
    status: status
  })
end

for {title, kind, amount, note, status, meeting} <- [
      {"Budgetram Q4 — total", "budget", 12_400_000, "Fastställd ram", "godkand", l_mote_13okt},
      {"Rekrytering utvecklare (2 st)", "utgift", 180_000, "Rekryteringskostnad", "att_godkanna",
       l_mote_13okt},
      {"Nya prislistor — tryck och utskick", "utgift", 45_000, "Kundkommunikation", "godkand",
       l_mote_29sep},
      {"Intäkt ny prismodell Q4", "intakt", 900_000, "Prognos", "att_godkanna", l_mote_29sep}
    ] do
  Repo.insert!(%FinanceEntry{
    space_id: ledning.id,
    meeting_id: meeting.id,
    title: title,
    kind: kind,
    amount: amount,
    note: note,
    status: status
  })
end

Seed.Helpers.artifact!(
  ledning,
  l_beslut,
  "Beslutslogg ledningsgrupp 2026 — export",
  "CSV",
  "arkiverad",
  "Minute-keeper",
  "14 kB",
  Seed.Helpers.ago(5)
)

Seed.Helpers.artifact!(
  ledning,
  l_mote,
  "Mötesanteckningar — ledningsmöte 13 okt",
  "PDF",
  "signerad",
  "Theresia Lundberg",
  "121 kB",
  Seed.Helpers.ago(2)
)

Seed.Helpers.artifact!(
  ledning,
  l_ekonomi,
  "Månadsrapport augusti",
  "PDF",
  "godkänd",
  "Marcus Nilsson",
  "86 kB",
  Seed.Helpers.ago(30)
)

Seed.Helpers.passage!(
  ledning,
  "Agenda 20 okt skapad från inkomna ärenden",
  Seed.Helpers.ago(0, 3),
  to: l_agenda,
  item: l_it_agenda
)

Seed.Helpers.passage!(
  ledning,
  "Ledningsmöte 13 okt passerade från Möte till Beslut",
  Seed.Helpers.ago(2, 1),
  from: l_mote,
  to: l_beslut
)

Seed.Helpers.passage!(ledning, "Beslut 'budgetram Q4' loggat", Seed.Helpers.ago(2, 2))

Seed.Helpers.passage!(
  ledning,
  "Uppgift 'Teknisk riskanalys' blev försenad",
  Seed.Helpers.ago(0, 8),
  from: l_beslut,
  to: l_uppgifter
)

Seed.Helpers.mail!(ledning, l_agenda, %{
  from: "Johanna Persson",
  from_email: "johanna.persson@acme.se",
  subject: "Punkt till agendan — lokalfrågan",
  at: Seed.Helpers.ago(0, 4),
  confidence: "high",
  body: [
    "Hej,",
    "Vill lägga till lokalfrågan på nästa ledningsmöte. Jag har tagit fram tre alternativ.",
    "Johanna"
  ]
})

Seed.Helpers.mail!(ledning, l_uppgifter, %{
  from: "Henrik Sandberg",
  from_email: "henrik.sandberg@acme.se",
  subject: "Status riskanalys",
  at: Seed.Helpers.ago(1, 2),
  confidence: "medium",
  note: "osäker — bekräfta routing",
  body: [
    "Hej,",
    "Riskanalysen blir klar i slutet av veckan, jag behöver ytterligare några dagar.",
    "Henrik"
  ]
})

Seed.Helpers.mail!(ledning, l_ekonomi, %{
  from: "Marcus Nilsson",
  from_email: "marcus@acme.se",
  subject: "Månadsrapport september",
  at: Seed.Helpers.ago(1, 5),
  confidence: "high",
  body: [
    "Hej,",
    "Bifogar månadsrapporten för september inför ledningsmötet.",
    "Marcus"
  ]
})

Repo.insert!(%OutboxMessage{
  space_id: ledning.id,
  state: "queued",
  from: "Agenda",
  to: "ledningsgruppen@acme.se",
  subject: "Kallelse ledningsmöte 20 okt",
  preview: "Hej, bifogat finns dagordning för ledningsmötet den 20 oktober…",
  status_note: "väntar på godkännande",
  occurred_at: Seed.Helpers.ago(0)
})

Repo.insert!(%OutboxMessage{
  space_id: ledning.id,
  state: "sent",
  from: "Beslut",
  to: "ledningsgruppen@acme.se",
  subject: "Beslut från ledningsmöte 13 okt",
  preview: "",
  passage_note: "Möte → Beslut",
  occurred_at: Seed.Helpers.ago(2)
})

for {name, role, email, group, rooms} <- [
      {"Theresia Lundberg", "VD", "theresia.lundberg@acme.se", "intern", ["Agenda", "Beslut"]},
      {"Marcus Nilsson", "CFO", "marcus@acme.se", "intern", ["Ekonomi"]},
      {"Johanna Persson", "COO", "johanna.persson@acme.se", "intern", ["Uppgifter"]},
      {"Henrik Sandberg", "CTO", "henrik.sandberg@acme.se", "intern", ["Uppgifter"]},
      {"Emma Falk", "HR-chef", "emma.falk@acme.se", "intern", ["Uppgifter"]},
      {"Minute-keeper", "Beslut & uppgifter", nil, "ai", ["Beslut", "Uppgifter"]}
    ] do
  Seed.Helpers.contact!(ledning, name, role, email, group, rooms)
end

# ================== Space: Bolagsstämma (Gimic) ==================

stamma =
  Repo.insert!(%Space{
    name: "Bolagsstämma",
    address: "bolagsstamma-gimic@m4w.ai",
    category: "Board",
    goal:
      "Driv bolagsstämma från kallelse till signerat och registrerat protokoll med full spårbarhet av beslut."
  })

link!.(karin, stamma)

s_kallelse =
  Seed.Helpers.room!(
    stamma,
    "Kallelse",
    0,
    "ai",
    "AI · Convocation Agent",
    "Kallelse utskickad till alla aktieägare",
    "öppnar när styrelsen beslutat att kalla"
  )

s_dagordning =
  Seed.Helpers.room!(
    stamma,
    "Dagordning & underlag",
    1,
    "mixed",
    "AI + Styrelseordförande",
    "Dagordning och förslag till beslut klara",
    "öppnar när kallelsen är skickad"
  )

s_stamma =
  Seed.Helpers.room!(
    stamma,
    "Stämma",
    2,
    "human",
    "Människor",
    "Stämman genomförd",
    "öppnar när stämmodatumet inträffar"
  )

s_protokoll =
  Seed.Helpers.room!(
    stamma,
    "Protokoll & e-signering",
    3,
    "mixed",
    "AI · Minute-keeper + Ordförande",
    "Protokoll signerat av ordförande och justerare",
    "öppnar när stämman avslutats"
  )

s_arkiv =
  Seed.Helpers.room!(
    stamma,
    "Registrering & arkiv",
    4,
    "ai",
    "AI",
    "Beslut loggade och anmälda till Bolagsverket",
    "stängd terminalstation"
  )

_it_s_kallelse =
  Seed.Helpers.item!(
    s_kallelse,
    "Extra bolagsstämma 24 sep",
    "väntar på svar från 2 av 9 aktieägare",
    "waiting"
  )

it_s_dagordning =
  Seed.Helpers.item!(
    s_dagordning,
    "Dagordning extra stämma",
    "4 punkter, 1 väntar på godkännande",
    "human"
  )

_it_s_stamma =
  Seed.Helpers.item!(s_stamma, "Extra bolagsstämma 24 sep", "pågår nu", "live")

it_s_protokoll =
  Seed.Helpers.item!(
    s_protokoll,
    "Protokoll extra stämma",
    "väntar på signering från justerare",
    "human"
  )

_it_s_arkiv =
  Seed.Helpers.item!(s_arkiv, "7 stämmobeslut loggade", "senaste: nyemission", "done")

stamma_attendees = fn present ->
  [
    %{"name" => "Karin Lindqvist", "role" => "Ordförande", "present" => present},
    %{"name" => "Therese Lundstedt", "role" => "Aktieägare", "present" => present},
    %{"name" => "Marcus Nilsson", "role" => "Aktieägare", "present" => present}
  ]
end

Repo.insert!(%Meeting{
  space_id: stamma.id,
  title: "Extra bolagsstämma 24 sep 2026",
  occurred_at: Seed.Helpers.ago(-1),
  status: "planerat",
  location: "Digitalt · Teams",
  attendees: stamma_attendees.(nil)
})

stamma_extra =
  Repo.insert!(%Meeting{
    space_id: stamma.id,
    title: "Extra bolagsstämma 9 sep 2026",
    occurred_at: Seed.Helpers.ago(30),
    status: "genomfört",
    location: "Huvudkontoret, Stockholm",
    attendees: stamma_attendees.(true)
  })

for {text, outcome, votes} <- [
      {"Val av ordförande och justerare", "Bifall", "3 för, 0 emot"},
      {"Dagordning godkänd", "Bifall", "3 för, 0 emot"},
      {"Nyemission och ändring av bolagsordning", "Bifall", "3 för, 0 emot"}
    ] do
  Repo.insert!(%Decision{meeting_id: stamma_extra.id, text: text, outcome: outcome, votes: votes})
end

stamma_arsstamma =
  Repo.insert!(%Meeting{
    space_id: stamma.id,
    title: "Ordinarie årsstämma 12 maj 2026",
    occurred_at: Seed.Helpers.ago(150),
    status: "genomfört",
    location: "Huvudkontoret, Stockholm",
    attendees: stamma_attendees.(true)
  })

for {text, outcome, votes} <- [
      {"Resultat- och balansräkning fastställd", "Bifall", "3 för, 0 emot"},
      {"Utdelning bordlagd till extra stämma", "Bordlagt", "—"},
      {"Ansvarsfrihet för styrelsen", "Bifall", "2 för, 1 avstod"},
      {"Val av styrelse och revisor", "Bifall", "3 för, 0 emot"}
    ] do
  Repo.insert!(%Decision{
    meeting_id: stamma_arsstamma.id,
    text: text,
    outcome: outcome,
    votes: votes
  })
end

Seed.Helpers.artifact!(
  stamma,
  s_kallelse,
  "Kallelse till extra bolagsstämma",
  "PDF",
  "skickad",
  "Convocation Agent",
  "88 kB",
  Seed.Helpers.ago(15)
)

Seed.Helpers.artifact!(
  stamma,
  s_kallelse,
  "Fullmaktsmall",
  "DOCX",
  "mall",
  "Convocation Agent",
  "31 kB",
  Seed.Helpers.ago(15)
)

Seed.Helpers.artifact!(
  stamma,
  s_dagordning,
  "Dagordning — extra bolagsstämma",
  "DOCX",
  "utkast",
  "Ordförande",
  "40 kB",
  Seed.Helpers.ago(10)
)

Seed.Helpers.artifact!(
  stamma,
  s_protokoll,
  "Protokoll — extra bolagsstämma 9 sep 2026",
  "PDF",
  "signerad",
  "Karin Lindqvist",
  "176 kB",
  Seed.Helpers.ago(5)
)

arsredovisning =
  Repo.insert!(%Artifact{
    space_id: stamma.id,
    room_id: s_arkiv.id,
    title: "Årsredovisning 2025",
    kind: "PDF",
    status: "arkiverad",
    created_by: "Minute-keeper",
    size: "3 kB",
    url: "/frontend/mail/docs/arsredovisning-2025.pdf",
    occurred_at: Seed.Helpers.ago(150)
  })

Repo.insert!(%FinanceEntry{
  space_id: stamma.id,
  meeting_id: stamma_arsstamma.id,
  artifact_id: arsredovisning.id,
  title: "Årsredovisning 2025",
  kind: "arsredovisning",
  amount: 3_900_000,
  note: "Årets resultat",
  status: "godkand"
})

Seed.Helpers.artifact!(
  stamma,
  s_arkiv,
  "Beslutslogg bolagsstämmor — export",
  "CSV",
  "arkiverad",
  "Minute-keeper",
  "12 kB",
  Seed.Helpers.ago(4)
)

Seed.Helpers.passage!(
  stamma,
  "Kallelse skickad till 9 aktieägare",
  Seed.Helpers.ago(15, 2)
)

Seed.Helpers.passage!(
  stamma,
  "Svar från Therese Lundstedt registrerat",
  Seed.Helpers.ago(14, 5)
)

Seed.Helpers.passage!(
  stamma,
  "Dagordning passerade från Dagordning & underlag till Stämma",
  Seed.Helpers.ago(10, 1),
  from: s_dagordning,
  to: s_stamma,
  item: it_s_dagordning
)

Seed.Helpers.passage!(
  stamma,
  "Protokoll passerade från Stämma till Protokoll & e-signering",
  Seed.Helpers.ago(6),
  from: s_stamma,
  to: s_protokoll,
  item: it_s_protokoll
)

Seed.Helpers.passage!(stamma, "Protokoll signerat av ordförande", Seed.Helpers.ago(5, 3))
Seed.Helpers.passage!(stamma, "Protokoll signerat av justerare", Seed.Helpers.ago(5, 1))

Seed.Helpers.passage!(
  stamma,
  "Stämmobeslut passerade från Protokoll & e-signering till Registrering & arkiv",
  Seed.Helpers.ago(4),
  from: s_protokoll,
  to: s_arkiv
)

# Verklig kallelse (scripts/mail/bolagsstämma) — bilagorna (PDF) följer inte med i seeden.
Seed.Helpers.mail!(stamma, s_kallelse, %{
  from: "Therese Lundstedt",
  from_email: "therese.lundstedt@gimic.se",
  subject: "Kallelse till extra bolagsstämma - Gimic",
  at: ~U[2026-09-09 15:20:31Z],
  confidence: "high",
  body: [
    "Hej aktieägare i Gimic,",
    "Vi kallar härmed till en extra bolagsstämma den 23 september kl. 10.00-10.30. Se bifogad kallelse samt övriga handlingar.",
    "Anmäl ditt deltagande senast den 21 september till: therese.lundstedt@gimic.se - en kalenderinbjudan med möteslänk sänds ut vid anmälan.",
    "Bakgrund: Den extra bolagsstämman hanterar två ärenden:",
    "1. För att stärka eget kapital som under en period blivit ansträngt föreslås en kvittningsemission att genomföras där befintliga lån från två aktieägare avses kvittas mot aktier. Se fullständiga villkor, etc. i bifogade bilagor.",
    "2. Under 2024 togs ett stämmobeslut för att ge ut kvalificerade personaloptioner till anställda i Gimic. Av olika skäl har dessa optioner inte kommit i spel. Ett omtag föreslås nu då tidigare pott inte längre blir aktuell och beslut tas om nytt optionsprogram. Se fullständiga villkor, etc. i bifogad bilaga.",
    "Har ni frågor är ni självklart välkomna att höra av er till styrelse eller VD.",
    "Vänliga hälsningar,",
    "/Gimics styrelse gm Therese Lundstedt",
    "Therese Lundstedt, VD, Gimic AB"
  ]
})

Seed.Helpers.mail!(stamma, s_kallelse, %{
  from: "Karin Lindqvist",
  from_email: "karin.lindqvist@gimic.se",
  subject: "Re: kallelse extra bolagsstämma",
  at: Seed.Helpers.ago(14, 6),
  confidence: "high",
  body: [
    "Hej,",
    "Bekräftar att jag deltar på stämman och leder den som ordförande.",
    "Karin"
  ]
})

Seed.Helpers.mail!(stamma, s_dagordning, %{
  from: "Karin Lindqvist",
  from_email: "karin.lindqvist@gimic.se",
  subject: "Punkt om nyemission till dagordningen",
  at: Seed.Helpers.ago(11),
  confidence: "high",
  body: [
    "Hej,",
    "Lägg till en punkt om nyemission och ändring av bolagsordningen på dagordningen.",
    "Karin"
  ]
})

# Verklig Scrive-bekräftelse (scripts/mail/bolagsstämma) — det signerade protokollet (PDF) följer inte med.
Seed.Helpers.mail!(stamma, s_protokoll, %{
  from: "Therese Lundstedt via Scrive",
  from_email: "noreply@scrive.com",
  subject: "Bekräftelse: e-signerat dokument Protokoll - extra bolagsstämma Gimic 2026-09-24",
  at: ~U[2026-09-24 12:43:31Z],
  confidence: "high",
  body: [
    "Dokumentet Protokoll - extra bolagsstämma Gimic 2026-09-24 har signerats av Stefan Axelsson och Marcus Nilsson.",
    "Det färdigställda dokumentet bifogas med detta mail.",
    "E-signing powered by Scrive"
  ]
})

Seed.Helpers.contact!(
  stamma,
  "Karin Lindqvist",
  "Ordförande",
  "karin.lindqvist@gimic.se",
  "intern",
  [
    "Dagordning & underlag",
    "Protokoll & e-signering"
  ]
)

Seed.Helpers.contact!(
  stamma,
  "Therese Lundstedt",
  "Aktieägare",
  "therese.lundstedt@gimic.se",
  "intern",
  [
    "Kallelse",
    "Stämma"
  ]
)

Seed.Helpers.contact!(stamma, "Convocation Agent", "Kallelse & fullmakter", nil, "ai", [
  "Kallelse"
])

Seed.Helpers.contact!(stamma, "Minute-keeper", "Protokoll & arkiv", nil, "ai", [
  "Protokoll & e-signering",
  "Registrering & arkiv"
])

# ================== Space: Projektuppföljning ==================

projekt =
  Repo.insert!(%Space{
    name: "Projektuppföljning",
    address: "projekt-skolappen@m4w.ai",
    category: "Service",
    goal:
      "Håll koll på projektet: fånga beslut, skapa uppgifter med ägare, och följ upp deadlines."
  })

link!.(marcus, projekt)

p_inkorg =
  Seed.Helpers.room!(
    projekt,
    "Inkorg",
    0,
    "ai",
    "AI",
    "Nya mail klassificerade",
    "öppnar när typ ≠ okänd"
  )

p_beslut =
  Seed.Helpers.room!(
    projekt,
    "Beslut",
    1,
    "mixed",
    "AI + Projektledare",
    "Beslut identifierade och bekräftade",
    "öppnar när bekräftat av PL"
  )

p_uppgifter =
  Seed.Helpers.room!(
    projekt,
    "Uppgifter",
    2,
    "mixed",
    "AI + Team",
    "Uppgifter skapade med ägare",
    "öppnar när ägare = satt"
  )

p_uppfoljning =
  Seed.Helpers.room!(
    projekt,
    "Uppföljning",
    3,
    "ai",
    "AI",
    "Påminnelser skickade vid avvikelse",
    "öppnar när status = klar"
  )

p_klart =
  Seed.Helpers.room!(
    projekt,
    "Klart",
    4,
    "ai",
    "AI",
    "Leverans bekräftad av kund",
    "stängd terminalstation"
  )

Seed.Helpers.item!(p_inkorg, "8 nya mail att klassificera", "äldsta: 2h", "waiting")

p_it_beslut1 =
  Seed.Helpers.item!(p_beslut, "Byte av API-leverantör", "väntar bekräftelse", "human")

Seed.Helpers.item!(p_beslut, "Skjuta release v0.9 → v1.0", "väntar bekräftelse", "human")
Seed.Helpers.item!(p_beslut, "Lägg till svenskt språkstöd", "väntar bekräftelse", "human")

p_it_uppgift1 =
  Seed.Helpers.item!(p_uppgifter, "Marcus · kodgranskning fre", "deadline om 2 dagar", "running")

Seed.Helpers.item!(p_uppgifter, "Lina · kundavstämning", "deadline om 4 dagar", "running")
Seed.Helpers.item!(p_uppfoljning, "Designgranskning v0.8", "1 deadline överskriden", "amber")
Seed.Helpers.item!(p_klart, "Leverans v.51", "bekräftad av kund", "done")

Seed.Helpers.artifact!(
  projekt,
  p_uppfoljning,
  "Statusrapport v.50 — Skolappen",
  "PDF",
  "skickad",
  "Routing Agent",
  "124 kB",
  Seed.Helpers.ago(0, 15, 30)
)

Seed.Helpers.artifact!(
  projekt,
  p_uppgifter,
  "Uppgiftslista — aktiva ägare & deadlines",
  "CSV",
  "uppdaterad",
  "Routing Agent",
  "12 kB",
  Seed.Helpers.ago(1, 9, 58)
)

Seed.Helpers.artifact!(
  projekt,
  p_beslut,
  "Beslutslogg — projektbeslut",
  "CSV",
  "arkiverad",
  "Projektledare",
  "9 kB",
  Seed.Helpers.ago(14)
)

Seed.Helpers.artifact!(
  projekt,
  p_klart,
  "Leveranskvitto v.51",
  "PDF",
  "bekräftad",
  "Skolappen AB",
  "88 kB",
  Seed.Helpers.ago(17)
)

Seed.Helpers.passage!(
  projekt,
  "Beslut 'API-leverantör' passerade från Inkorg till Beslut",
  Seed.Helpers.ago(0, 8, 42),
  from: p_inkorg,
  to: p_beslut,
  item: p_it_beslut1
)

Seed.Helpers.passage!(
  projekt,
  "Uppgift 'kodgranskning fre' tilldelad Marcus",
  Seed.Helpers.ago(0, 9, 58),
  item: p_it_uppgift1
)

Seed.Helpers.passage!(
  projekt,
  "Påminnelse skickad: designgranskning v0.8 försenad",
  Seed.Helpers.ago(0, 12, 13)
)

Seed.Helpers.passage!(
  projekt,
  "Mail 'Re: timeline' routat till Inkorg",
  Seed.Helpers.ago(0, 13, 48)
)

Seed.Helpers.passage!(
  projekt,
  "Leverans v.51 passerade markerad som klar",
  Seed.Helpers.ago(1, 7, 5)
)

Seed.Helpers.mail!(projekt, p_uppfoljning, %{
  from: "Skolappen AB",
  from_email: "kontakt@skolappen.se",
  subject: "Re: designgranskning v0.8",
  at: Seed.Helpers.ago(0, 14, 8),
  confidence: "high",
  body: [
    "Hej,",
    "Vi har tittat igenom designgranskningen för v0.8 och har några mindre kommentarer — inget som borde påverka tidsplanen.",
    "Hälsningar, Skolappen AB"
  ]
})

Seed.Helpers.mail!(projekt, p_beslut, %{
  from: "Marcus Nilsson",
  from_email: "marcus@acme.se",
  subject: "Beslut: byte av API-leverantör",
  at: Seed.Helpers.ago(0, 15, 45),
  confidence: "high",
  body: [
    "Hej,",
    "Vi går vidare med byte av API-leverantör enligt förslaget. Kan ni driva vidare i nästa steg?",
    "Marcus"
  ]
})

Seed.Helpers.mail!(projekt, p_uppgifter, %{
  from: "Lina Ekström",
  from_email: "lina.ekstrom@acme.se",
  subject: "Klar med kundavstämning",
  at: Seed.Helpers.ago(1, 7, 20),
  confidence: "high",
  body: ["Hej,", "Kundavstämningen är klar för denna vecka — inga avvikelser att flagga.", "Lina"]
})

Seed.Helpers.mail!(projekt, p_inkorg, %{
  from: "okänd avsändare",
  from_email: "faktura@leverantor.example",
  subject: "Angående fakturan från förra veckan",
  at: Seed.Helpers.ago(1, 12, 55),
  confidence: "medium",
  note: "osäker — bekräfta routing",
  body: [
    "Hej,",
    "Återkommer angående fakturan vi skickade förra veckan — undrar om ni hann titta på den?",
    "Mvh"
  ]
})

Seed.Helpers.contact!(projekt, "Sofia Ek", "Projektledare", "sofia.ek@acme.se", "intern", [
  "Beslut"
])

Seed.Helpers.contact!(projekt, "Marcus Nilsson", "Utvecklare", "marcus@acme.se", "intern", [
  "Uppgifter"
])

Seed.Helpers.contact!(projekt, "Lina Berg", "Kundansvarig", "lina.berg@acme.se", "intern", [
  "Uppgifter"
])

Seed.Helpers.contact!(projekt, "Skolappen AB", "Kund", "kontakt@skolappen.se", "extern", ["Klart"])

Seed.Helpers.contact!(projekt, "Routing Agent", "Klassificering & uppföljning", nil, "ai", [
  "Inkorg",
  "Uppföljning"
])

# ================== Space: Bokföring ==================

bokforing =
  Repo.insert!(%Space{
    name: "Bokföring",
    address: "bokforing-acme@m4w.ai",
    category: "Accounting",
    goal:
      "Ta fakturor från mail, extrahera fält, matcha mot inköpsorder, godkänn avvikelser och exportera till Fortnox."
  })

link!.(marcus, bokforing)

b_extraktion =
  Seed.Helpers.room!(
    bokforing,
    "Extraktion",
    0,
    "ai",
    "AI",
    "Fält extraherade från faktura",
    "öppnar när alla obligatoriska fält ≠ tomt"
  )

b_matchning =
  Seed.Helpers.room!(
    bokforing,
    "Matchning",
    1,
    "ai",
    "AI",
    "Matchad mot inköpsorder/avtal",
    "öppnar när match = OK eller avvikelse godkänd"
  )

b_godkannande =
  Seed.Helpers.room!(
    bokforing,
    "Godkännande",
    2,
    "human",
    "Ekonomiansvarig",
    "Avvikelser granskade manuellt",
    "öppnar när signerad av ek.ansv."
  )

b_export =
  Seed.Helpers.room!(
    bokforing,
    "Export",
    3,
    "ai",
    "AI",
    "Exporterad till Fortnox",
    "stängd terminalstation"
  )

Seed.Helpers.item!(b_extraktion, "Faktura #2024-118 · Telia", "4 200 kr", "running")
Seed.Helpers.item!(b_extraktion, "Faktura #2024-119 · Företagshälsan", "8 750 kr", "running")

b_it_match =
  Seed.Helpers.item!(
    b_matchning,
    "Faktura #2024-117 · AWS",
    "match OK · 1 avvikelse hittad",
    "amber"
  )

b_it_godkann =
  Seed.Helpers.item!(b_godkannande, "Faktura #2024-117 · AWS", "väntar på godkännande", "human")

Seed.Helpers.item!(b_export, "23 fakturor denna vecka", "senast: #2024-116", "done")

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Alla affärshändelser bokförda",
  ref: "BFL 4 kap. 1 §",
  status: "uppfyllt",
  description: "Varje affärshändelse ska bokföras så snart det kan ske.",
  state: "142 av 142 händelser bokförda denna period"
})

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Korrekta verifikationer",
  ref: "BFL 5 kap. 6–10 §",
  status: "avvikelse",
  description: "Varje bokföringspost ska styrkas av en verifikation med rätt innehåll.",
  state: "1 faktura saknar fullständigt verifikat — #2024-117 väntar på godkännande"
})

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Löpande registrering",
  ref: "BFL 5 kap. 1–2 §",
  status: "uppfyllt",
  description: "Affärshändelser ska registreras löpande och i kronologisk ordning.",
  state: "Registreras dagligen · senast idag 11:08"
})

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Spårbarhet",
  ref: "BFL 5 kap. 1 §",
  status: "uppfyllt",
  description: "Det ska gå att följa en post från verifikation till bokslut och tillbaka.",
  state: "Varje verifikation länkad till sin Passage — full kedja"
})

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Avstämningar",
  ref: "God redovisningssed",
  status: "pagar",
  description: "Konton stäms av mot externa underlag, t.ex. bank och leverantörsreskontra.",
  state: "Bankavstämning nov klar · december pågår"
})

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Arkivering i minst sju år",
  ref: "BFL 7 kap. 2 §",
  status: "uppfyllt",
  description: "Räkenskapsinformation ska bevaras i minst sju år i ursprungligt skick.",
  state: "Allt arkiverat oföränderligt t.o.m. 2032"
})

Repo.insert!(%ComplianceCheck{
  space_id: bokforing.id,
  title: "Korrekt bokslut / årsredovisning",
  ref: "BFL 6 kap. · ÅRL",
  status: "pagar",
  description: "Räkenskapsåret avslutas med ett bokslut upprättat enligt god redovisningssed.",
  state: "Bokslut 2025 förbereds · deadline 30 jun 2026"
})

Repo.insert!(%Verification{
  space_id: bokforing.id,
  ver: "V-2024-118",
  occurred_at: Seed.Helpers.ago(0),
  supplier: "Telia AB",
  amount: "4 200 kr",
  status: "bokförd",
  archive_until: "t.o.m. 2033",
  trace_from_room_id: b_extraktion.id,
  trace_to_room_id: b_matchning.id
})

Repo.insert!(%Verification{
  space_id: bokforing.id,
  ver: "V-2024-117",
  occurred_at: Seed.Helpers.ago(0),
  supplier: "AWS",
  amount: "20 140 kr",
  status: "avvikelse",
  archive_until: "t.o.m. 2033",
  trace_from_room_id: b_matchning.id,
  trace_to_room_id: b_godkannande.id
})

Repo.insert!(%Verification{
  space_id: bokforing.id,
  ver: "V-2024-116",
  occurred_at: Seed.Helpers.ago(1),
  supplier: "Klarna for Business",
  amount: "1 290 kr",
  status: "exporterad",
  archive_until: "t.o.m. 2033",
  trace_from_room_id: b_export.id,
  trace_to_room_id: nil
})

Repo.insert!(%Verification{
  space_id: bokforing.id,
  ver: "V-2024-115",
  occurred_at: Seed.Helpers.ago(11),
  supplier: "Företagshälsan",
  amount: "8 750 kr",
  status: "exporterad",
  archive_until: "t.o.m. 2032",
  trace_from_room_id: b_export.id,
  trace_to_room_id: nil
})

Repo.insert!(%Verification{
  space_id: bokforing.id,
  ver: "V-2024-114",
  occurred_at: Seed.Helpers.ago(14),
  supplier: "Telia AB",
  amount: "4 200 kr",
  status: "exporterad",
  archive_until: "t.o.m. 2032",
  trace_from_room_id: b_export.id,
  trace_to_room_id: nil
})

Repo.insert!(%Verification{
  space_id: bokforing.id,
  ver: "V-2024-113",
  occurred_at: Seed.Helpers.ago(20),
  supplier: "Fortum",
  amount: "3 615 kr",
  status: "exporterad",
  archive_until: "t.o.m. 2032",
  trace_from_room_id: b_export.id,
  trace_to_room_id: nil
})

Seed.Helpers.artifact!(
  bokforing,
  b_export,
  "SIE-fil — november 2025",
  "SIE",
  "exporterad",
  "Fortnox",
  "62 kB",
  Seed.Helpers.ago(11)
)

Seed.Helpers.artifact!(
  bokforing,
  b_export,
  "Fortnox-export — 23 verifikationer v.50",
  "SIE",
  "exporterad",
  "Fortnox",
  "48 kB",
  Seed.Helpers.ago(1, 4, 50)
)

Seed.Helpers.artifact!(
  bokforing,
  b_export,
  "Momsrapport Q4 2025 — underlag",
  "PDF",
  "utkast",
  "AI",
  "156 kB",
  Seed.Helpers.ago(0, 4, 52)
)

Seed.Helpers.artifact!(
  bokforing,
  b_matchning,
  "Bankavstämning november",
  "PDF",
  "arkiverad",
  "AI",
  "74 kB",
  Seed.Helpers.ago(4)
)

Seed.Helpers.artifact!(
  bokforing,
  b_godkannande,
  "Faktura #2024-117 — AWS",
  "PDF",
  "granskas",
  "Ekonomiansvarig",
  "112 kB",
  Seed.Helpers.ago(0)
)

Seed.Helpers.passage!(
  bokforing,
  "Faktura #2024-117 passerade från Matchning till Godkännande",
  Seed.Helpers.ago(0, 9, 28),
  from: b_matchning,
  to: b_godkannande,
  item: b_it_godkann
)

Seed.Helpers.passage!(
  bokforing,
  "Faktura #2024-118 från Telia extraherad",
  Seed.Helpers.ago(0, 10, 5)
)

Seed.Helpers.passage!(
  bokforing,
  "Faktura #2024-116 exporterad till Fortnox",
  Seed.Helpers.ago(0, 12, 52)
)

Seed.Helpers.mail!(bokforing, b_extraktion, %{
  from: "Telia AB",
  from_email: "faktura@telia.se",
  subject: "Faktura 2024-118 · 4 200 kr",
  at: Seed.Helpers.ago(0, 13, 56),
  confidence: "high",
  body: [
    "Hej,",
    "Bifogat finner ni faktura 2024-118 avseende företagsabonnemang, 4 200 kr. Förfallodatum om 30 dagar.",
    "Telia Företag"
  ]
})

Seed.Helpers.mail!(bokforing, b_matchning, %{
  from: "AWS Billing",
  from_email: "billing@aws.example",
  subject: "Invoice 2024-117 · $1,940.00",
  at: Seed.Helpers.ago(0, 14, 20),
  confidence: "high",
  body: [
    "Hello,",
    "Your invoice 2024-117 for this billing period totals $1,940.00. Payment is due within 14 days.",
    "AWS Billing"
  ]
})

Seed.Helpers.mail!(bokforing, b_export, %{
  from: "Klarna for Business",
  from_email: "business@klarna.example",
  subject: "Faktura 2024-116 · 1 290 kr",
  at: Seed.Helpers.ago(1, 1, 10),
  confidence: "high",
  body: [
    "Hej,",
    "Bifogat finner ni er faktura för Klarna for Business, 1 290 kr. Betalning sker automatiskt via autogiro.",
    "Klarna for Business"
  ]
})

Seed.Helpers.mail!(bokforing, b_extraktion, %{
  from: "okänd@leverantör.se",
  from_email: "okänd@leverantör.se",
  subject: "Bifogad faktura — se pdf",
  at: Seed.Helpers.ago(1, 9, 48),
  confidence: "medium",
  note: "osäker — bekräfta routing",
  body: ["Hej,", "Bifogar faktura enligt överenskommelse, se pdf. Hör av er vid frågor.", "Mvh"]
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Telia AB",
  subject: "Faktura 2024-118 · 4 200 kr",
  at: Seed.Helpers.ago(0, 13, 56),
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Företagshälsan",
  subject: "Faktura 2024-119 · 8 750 kr",
  at: Seed.Helpers.ago(0, 14, 39),
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "AWS Billing",
  subject: "Invoice 2024-117 · $1,940.00",
  at: Seed.Helpers.ago(1, 1, 10),
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Klarna for Business",
  subject: "Faktura 2024-115 · 1 290 kr",
  at: Seed.Helpers.ago(3),
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Marcus (CFO)",
  subject: "Re: ny rutin för avvikelser",
  at: Seed.Helpers.ago(4),
  use: false
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Fortnox Support",
  subject: "Re: API-nyckel förnyad",
  at: Seed.Helpers.ago(5),
  use: false
})

Seed.Helpers.contact!(
  bokforing,
  "Marcus Nilsson",
  "Ekonomiansvarig · CFO",
  "marcus@acme.se",
  "intern",
  ["Godkännande"]
)

Seed.Helpers.contact!(bokforing, "Telia AB", "Leverantör", "faktura@telia.se", "extern", [
  "Extraktion"
])

Seed.Helpers.contact!(
  bokforing,
  "Företagshälsan",
  "Leverantör",
  "faktura@foretagshalsan.se",
  "extern",
  ["Extraktion"]
)

Seed.Helpers.contact!(
  bokforing,
  "AWS Billing",
  "Leverantör",
  "billing@aws.amazon.com",
  "extern",
  ["Matchning"]
)

Seed.Helpers.contact!(
  bokforing,
  "Klarna for Business",
  "Leverantör",
  "faktura@klarna.com",
  "extern",
  ["Extraktion"]
)

Seed.Helpers.contact!(
  bokforing,
  "Fortnox Support",
  "Systemleverantör",
  "support@fortnox.se",
  "extern",
  ["Export"]
)

Seed.Helpers.contact!(bokforing, "Extraktions-AI", "Fältextraktion & export", nil, "ai", [
  "Extraktion",
  "Matchning",
  "Export"
])

# ================== Space: Fakturering (Sara, no org) ==================

fakturering =
  Repo.insert!(%Space{
    name: "Fakturering",
    address: "fakturering-ahlen@m4w.ai",
    category: "Sales",
    goal:
      "Skicka fakturor till kunder utifrån loggad tid, följ upp betalning, och håll koll på obetalda fakturor."
  })

link!.(sara, fakturering)

f_tidslogg =
  Seed.Helpers.room!(
    fakturering,
    "Tidslogg",
    0,
    "ai",
    "AI",
    "Loggad tid sammanställd till fakturaunderlag",
    "öppnar när perioden avslutas"
  )

f_fakturering =
  Seed.Helpers.room!(
    fakturering,
    "Fakturering",
    1,
    "mixed",
    "AI + Sara",
    "Faktura skapad och godkänd",
    "öppnar när Sara godkänner"
  )

f_uppfoljning =
  Seed.Helpers.room!(
    fakturering,
    "Uppföljning",
    2,
    "ai",
    "AI",
    "Betalning bevakad, påminnelse skickad vid försening",
    "öppnar när betald = sant"
  )

f_betald =
  Seed.Helpers.room!(
    fakturering,
    "Betald",
    3,
    "ai",
    "AI",
    "Betalning bekräftad och arkiverad",
    "stängd terminalstation"
  )

Seed.Helpers.item!(f_tidslogg, "Konsulttid — vecka 26", "18,5 h loggade", "running")

f_it_fakt =
  Seed.Helpers.item!(
    f_fakturering,
    "Faktura · Nordic Retail AB",
    "12 400 kr · väntar på godkännande",
    "human"
  )

Seed.Helpers.item!(
  f_uppfoljning,
  "Faktura #118 · Butikskedjan AB",
  "förfaller om 3 dagar",
  "running"
)

Seed.Helpers.item!(f_betald, "6 fakturor betalda denna månad", "senast: #117", "done")

Seed.Helpers.artifact!(
  fakturering,
  f_fakturering,
  "Faktura #117 — Butikskedjan AB",
  "PDF",
  "skickad",
  "Sara Ahlén",
  "64 kB",
  Seed.Helpers.ago(9)
)

Seed.Helpers.artifact!(
  fakturering,
  f_fakturering,
  "Faktura #116 — Nordic Retail AB",
  "PDF",
  "bekräftad",
  "Sara Ahlén",
  "58 kB",
  Seed.Helpers.ago(17)
)

Seed.Helpers.artifact!(
  fakturering,
  f_tidslogg,
  "Tidsunderlag — vecka 25",
  "CSV",
  "arkiverad",
  "AI",
  "6 kB",
  Seed.Helpers.ago(70)
)

Seed.Helpers.passage!(
  fakturering,
  "Tidsunderlag vecka 26 passerade från Tidslogg till Fakturering",
  Seed.Helpers.ago(0, 14, 48),
  from: f_tidslogg,
  to: f_fakturering,
  item: f_it_fakt
)

Seed.Helpers.passage!(
  fakturering,
  "Faktura #117 passerade från Fakturering till Uppföljning",
  Seed.Helpers.ago(1, 6, 20),
  from: f_fakturering,
  to: f_uppfoljning
)

Seed.Helpers.passage!(
  fakturering,
  "Faktura #117 skickad till Butikskedjan AB",
  Seed.Helpers.ago(9)
)

Seed.Helpers.passage!(fakturering, "Betalning för faktura #116 bekräftad", Seed.Helpers.ago(17))

Seed.Helpers.mail!(fakturering, f_tidslogg, %{
  from: "Nordic Retail AB",
  from_email: "ekonomi@nordicretail.se",
  subject: "Godkänner tidrapport vecka 26",
  at: Seed.Helpers.ago(0, 15, 20),
  confidence: "high",
  body: [
    "Hej Sara,",
    "Vi godkänner tidrapporten för vecka 26 — 18,5 timmar stämmer med vår logg. Gå vidare med fakturering.",
    "Hälsningar, Nordic Retail AB"
  ]
})

Seed.Helpers.mail!(fakturering, f_uppfoljning, %{
  from: "Butikskedjan AB",
  from_email: "ekonomi@butikskedjan.se",
  subject: "Fråga om faktura #117",
  at: Seed.Helpers.ago(1, 10, 58),
  confidence: "high",
  body: [
    "Hej Sara,",
    "Vi undrar över radposten på faktura #117 — kan du specificera vilka dagar som ingår? Vill stämma av innan betalning.",
    "Mvh, Butikskedjan AB"
  ]
})

Repo.insert!(%OutboxMessage{
  space_id: fakturering.id,
  state: "queued",
  from: "Fakturering",
  to: "faktura@nordicretail.se",
  subject: "Faktura #118 — konsulttid vecka 26",
  preview: "Hej, bifogat faktura för utfört arbete vecka 26 enligt godkänd tidrapport…",
  status_note: "väntar på godkännande",
  occurred_at: Seed.Helpers.ago(0)
})

Repo.insert!(%OutboxMessage{
  space_id: fakturering.id,
  state: "sent",
  from: "Fakturering",
  to: "faktura@butikskedjan.se",
  subject: "Faktura #117",
  preview: "",
  passage_note: "Fakturering → Uppföljning",
  occurred_at: Seed.Helpers.ago(9)
})

Seed.Helpers.contact!(
  fakturering,
  "Sara Ahlén",
  "Enskild firma · Ahlén Konsult",
  "sara@ahlenkonsult.se",
  "intern",
  ["Fakturering"]
)

Seed.Helpers.contact!(
  fakturering,
  "Nordic Retail AB",
  "Kund",
  "faktura@nordicretail.se",
  "extern",
  ["Tidslogg", "Fakturering"]
)

Seed.Helpers.contact!(
  fakturering,
  "Butikskedjan AB",
  "Kund",
  "faktura@butikskedjan.se",
  "extern",
  ["Uppföljning"]
)

Seed.Helpers.contact!(fakturering, "Faktura-AI", "Fakturering & uppföljning", nil, "ai", [
  "Tidslogg",
  "Fakturering",
  "Uppföljning",
  "Betald"
])

# ================== Space: Aktieägaravtal ==================

avtal =
  Repo.insert!(%Space{
    name: "Aktieägaravtal",
    address: "aktieagaravtal-gimic@m4w.ai",
    category: "Legal",
    goal:
      "Följ aktieägaravtalet över tid: varje revision i en tidslinje, med ägarna som gällde vid varje ändring."
  })

link!.(karin, avtal)

a_utkast =
  Seed.Helpers.room!(
    avtal,
    "Utkast & förhandling",
    0,
    "mixed",
    "AI + Jurist",
    "Reviderat avtal förhandlat och överenskommet",
    "öppnar när en ändring föreslås"
  )

a_signering =
  Seed.Helpers.room!(
    avtal,
    "Signering",
    1,
    "mixed",
    "AI + Ordförande",
    "Avtalet signerat av alla parter",
    "öppnar när utkastet är överenskommet"
  )

a_gallande =
  Seed.Helpers.room!(
    avtal,
    "Gällande avtal",
    2,
    "ai",
    "AI",
    "Gällande version arkiverad",
    "stängd terminalstation"
  )

_it_a_utkast =
  Seed.Helpers.item!(
    a_utkast,
    "Tillägg: drag-along vid nyemission",
    "väntar på synpunkter",
    "human"
  )

_it_a_gallande =
  Seed.Helpers.item!(a_gallande, "Aktieägaravtal v3", "gällande sedan 24 sep", "done")

agreement_doc = fn title, at ->
  Seed.Helpers.artifact!(avtal, a_gallande, title, "PDF", "signerad", "Jurist", "180 KB", at)
end

for {version, title, summary, by, at, owners} <- [
      {"v1", "Aktieägaravtal Gimic AB",
       "Ursprungligt avtal vid bolagsbildningen: förköp, hembud och tag-along.",
       "Therese Lundstedt", ~U[2023-03-15 10:00:00Z],
       [
         %{"name" => "Therese Lundstedt", "shares" => 6_000},
         %{"name" => "Marcus Nilsson", "shares" => 3_000},
         %{"name" => "Karin Lindqvist", "shares" => 1_000}
       ]},
      {"v2", "Aktieägaravtal Gimic AB — tillägg om nytt ägande",
       "Marcus Nilsson köper 1 000 aktier av Therese; ny röstbindning vid styrelseval.",
       "Karin Lindqvist", ~U[2024-06-20 13:30:00Z],
       [
         %{"name" => "Therese Lundstedt", "shares" => 5_000},
         %{"name" => "Marcus Nilsson", "shares" => 4_000},
         %{"name" => "Karin Lindqvist", "shares" => 1_000}
       ]},
      {"v3", "Aktieägaravtal Gimic AB — kvittningsemission",
       "Två aktieägare kvittar lån mot aktier; drag-along skärps och Nordic Angels tillträder avtalet.",
       "Therese Lundstedt", ~U[2026-09-24 11:00:00Z],
       [
         %{"name" => "Therese Lundstedt", "shares" => 5_000},
         %{"name" => "Marcus Nilsson", "shares" => 5_500},
         %{"name" => "Karin Lindqvist", "shares" => 2_500},
         %{"name" => "Nordic Angels AB", "shares" => 2_000}
       ]}
    ] do
  doc = agreement_doc.("Aktieägaravtal #{version}.pdf", at)

  Repo.insert!(%AgreementRevision{
    space_id: avtal.id,
    artifact_id: doc.id,
    version: version,
    title: title,
    summary: summary,
    changed_by: by,
    effective_at: at,
    owners: owners
  })
end

# ================== Space: Aktiebok ==================

aktiebok =
  Repo.insert!(%Space{
    name: "Aktiebok",
    address: "aktiebok-gimic@m4w.ai",
    category: "Legal",
    goal:
      "För aktieboken löpande: varje nyemission och överlåtelse i en tidslinje, med ägarna efter varje förändring."
  })

link!.(karin, aktiebok)

ab_underlag =
  Seed.Helpers.room!(
    aktiebok,
    "Underlag",
    0,
    "mixed",
    "AI + Styrelseordförande",
    "Överlåtelse eller emission underbyggd med handlingar",
    "öppnar när en ägarförändring anmäls"
  )

ab_bok =
  Seed.Helpers.room!(
    aktiebok,
    "Aktiebok",
    1,
    "ai",
    "AI",
    "Aktieboken uppdaterad och arkiverad",
    "stängd terminalstation"
  )

_it_ab_underlag =
  Seed.Helpers.item!(ab_underlag, "Överlåtelse Nordic Angels", "väntar på köpebrev", "human")

_it_ab_bok = Seed.Helpers.item!(ab_bok, "Aktiebok nr 3", "gällande sedan 24 sep", "done")

for {version, title, summary, by, at, owners} <- [
      {"Nr 1", "Bolagsbildning", "Teckning av 10 000 aktier vid bolagsbildningen.",
       "Therese Lundstedt", ~U[2023-03-15 10:00:00Z],
       [
         %{"name" => "Therese Lundstedt", "shares" => 6_000},
         %{"name" => "Marcus Nilsson", "shares" => 3_000},
         %{"name" => "Karin Lindqvist", "shares" => 1_000}
       ]},
      {"Nr 2", "Överlåtelse", "Therese Lundstedt överlåter 1 000 aktier till Marcus Nilsson.",
       "Karin Lindqvist", ~U[2024-06-20 13:30:00Z],
       [
         %{"name" => "Therese Lundstedt", "shares" => 5_000},
         %{"name" => "Marcus Nilsson", "shares" => 4_000},
         %{"name" => "Karin Lindqvist", "shares" => 1_000}
       ]},
      {"Nr 3", "Kvittningsemission",
       "Nyemission av 3 000 aktier: Marcus (1 500), Karin (1 500) och Nordic Angels (2 000) via lån och kontant betalning.",
       "Therese Lundstedt", ~U[2026-09-24 11:00:00Z],
       [
         %{"name" => "Therese Lundstedt", "shares" => 5_000},
         %{"name" => "Marcus Nilsson", "shares" => 5_500},
         %{"name" => "Karin Lindqvist", "shares" => 2_500},
         %{"name" => "Nordic Angels AB", "shares" => 2_000}
       ]}
    ] do
  doc =
    Seed.Helpers.artifact!(
      aktiebok,
      ab_bok,
      "Aktiebok #{version}.pdf",
      "PDF",
      "signerad",
      "Styrelsen",
      "95 KB",
      at
    )

  Repo.insert!(%AgreementRevision{
    space_id: aktiebok.id,
    artifact_id: doc.id,
    version: version,
    title: title,
    summary: summary,
    changed_by: by,
    effective_at: at,
    owners: owners
  })
end

# ================== Space: Anställningsavtal ==================

anstallning =
  Repo.insert!(%Space{
    name: "Anställningsavtal",
    address: "anstallningsavtal-gimic@m4w.ai",
    category: "HR",
    goal:
      "Följ anställningsavtal från erbjudande till avslut: när en person anställs, under vilket avtal och kollektivavtal, och när de säger upp sig — med uppsägningstid och slutdatum."
  })

link!.(theresia, anstallning)
link!.(marcus, anstallning)

an_erbjudande =
  Seed.Helpers.room!(
    anstallning,
    "Erbjudande & avtal",
    0,
    "mixed",
    "AI + VD",
    "Anställningsavtal upprättat och signerat av båda parter",
    "öppnar när en person ska anställas"
  )

an_gallande =
  Seed.Helpers.room!(
    anstallning,
    "Gällande anställning",
    1,
    "ai",
    "AI",
    "Anställningen registrerad med avtalsvillkor och uppsägningstid",
    "öppnar när avtalet är signerat"
  )

an_uppsagning =
  Seed.Helpers.room!(
    anstallning,
    "Uppsägning & avslut",
    2,
    "mixed",
    "AI + Ekonomiansvarig",
    "Uppsägning bekräftad, slutlön och avslut hanterat",
    "öppnar när en person säger upp sig eller sägs upp"
  )

an_arkiv =
  Seed.Helpers.room!(
    anstallning,
    "Avslutade anställningar",
    3,
    "ai",
    "AI",
    "Avslutat avtal arkiverat",
    "stängd terminalstation"
  )

it_erbjudande =
  Seed.Helpers.item!(
    an_erbjudande,
    "Anställningsavtal — Johan Berg (utvecklare)",
    "väntar på signering",
    "human"
  )

it_gallande =
  Seed.Helpers.item!(
    an_gallande,
    "Elin Sjöberg — tillsvidare, 6 mån uppsägning",
    "anställd sedan 1 feb 2025",
    "done"
  )

it_uppsagning =
  Seed.Helpers.item!(
    an_uppsagning,
    "Oskar Ek — uppsägning från arbetstagaren",
    "uppsägningstid 3 mån, slutdatum 31 dec 2026",
    "human"
  )

it_arkiv =
  Seed.Helpers.item!(
    an_arkiv,
    "Maria Holm — avslutad 30 jun 2026",
    "visstidsanställning löpte ut",
    "done"
  )

# {namn, avtalsdokument, status, rum, tidpunkt, passage}
for {title, status, room, at} <- [
      {"Anställningsavtal Elin Sjöberg.pdf", "signerad", an_gallande, ~U[2025-01-15 09:00:00Z]},
      {"Anställningsavtal Oskar Ek.pdf", "signerad", an_uppsagning, ~U[2023-08-21 09:00:00Z]},
      {"Uppsägning Oskar Ek.pdf", "mottagen", an_uppsagning, ~U[2026-09-30 14:00:00Z]},
      {"Anställningsavtal Maria Holm (visstid).pdf", "signerad", an_arkiv,
       ~U[2025-07-01 09:00:00Z]},
      {"Anställningsavtal Johan Berg (utkast).pdf", "utkast", an_erbjudande,
       ~U[2026-10-05 10:00:00Z]}
    ] do
  Seed.Helpers.artifact!(anstallning, room, title, "PDF", status, "VD", "120 KB", at)
end

Seed.Helpers.passage!(
  anstallning,
  "Anställningsavtal för Elin Sjöberg signerat: tillsvidare, 6 månaders ömsesidig uppsägningstid, start 1 feb 2025.",
  ~U[2025-01-15 09:00:00Z],
  item: it_gallande,
  from: an_erbjudande,
  to: an_gallande
)

Seed.Helpers.passage!(
  anstallning,
  "Maria Holms visstidsanställning (1 jul 2025 – 30 jun 2026) löpte ut och arkiverades utan uppsägning.",
  ~U[2026-06-30 16:00:00Z],
  item: it_arkiv,
  from: an_gallande,
  to: an_arkiv
)

Seed.Helpers.passage!(
  anstallning,
  "Oskar Ek sade upp sig 30 sep 2026. Enligt avtalet från 21 aug 2023 gäller 3 månaders uppsägningstid — sista anställningsdag 31 dec 2026.",
  ~U[2026-09-30 14:00:00Z],
  item: it_uppsagning,
  from: an_gallande,
  to: an_uppsagning
)

Seed.Helpers.passage!(
  anstallning,
  "Anställningsavtal för Johan Berg skickat för signering, planerad start 1 jan 2027.",
  ~U[2026-10-05 10:00:00Z],
  item: it_erbjudande,
  to: an_erbjudande
)

Seed.Helpers.contact!(
  anstallning,
  "Theresia Lundberg",
  "VD",
  "theresia.lundberg@acme.se",
  "intern",
  [
    "Erbjudande & avtal",
    "Uppsägning & avslut"
  ]
)

Seed.Helpers.contact!(
  anstallning,
  "Marcus Nilsson",
  "Ekonomiansvarig · CFO",
  "marcus@acme.se",
  "intern",
  [
    "Gällande anställning",
    "Uppsägning & avslut"
  ]
)

# ================== Unclassified (global triage queue) ==================

Seed.Helpers.mail!(nil, nil, %{
  from: "Linda Forsén",
  from_email: "linda.forsen@example.se",
  subject: "Hej — kan ni hjälpa med en sak?",
  at: Seed.Helpers.ago(0, 4, 46),
  status: "unclassified",
  reason: "matchar inget Space",
  body: [
    "Hej,",
    "Vet inte riktigt vem jag ska vända mig till, men undrar om ni kan hjälpa till med något som inte riktigt passar in i våra vanliga flöden?",
    "Linda"
  ]
})

Seed.Helpers.mail!(nil, nil, %{
  from: "newsletter@nordicops.io",
  from_email: "newsletter@nordicops.io",
  subject: "Veckans nyhetsbrev — operations",
  at: Seed.Helpers.ago(1, 2, 0),
  status: "unclassified",
  reason: "ingen process passar",
  body: [
    "Hej,",
    "Här är veckans nyhetsbrev med tips och trender inom operations och processautomation.",
    "Nordic Ops Newsletter"
  ]
})

Seed.Helpers.mail!(nil, nil, %{
  from: "okänd@gmail.com",
  from_email: "okänd@gmail.com",
  subject: "Fråga om era tjänster",
  at: Seed.Helpers.ago(1),
  status: "unclassified",
  reason: "matchar inget Space",
  body: [
    "Hej,",
    "Såg er sida och undrar om ni tar emot nya kunder just nu? Vad kostar en enklare konsultinsats?",
    "Mvh"
  ]
})

IO.puts(
  "Seeded: #{Repo.aggregate(Space, :count)} spaces, #{Repo.aggregate(User, :count)} users, #{Repo.aggregate(Mail, :count)} mails."
)
