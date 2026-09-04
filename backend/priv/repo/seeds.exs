# Seeds the Ops domain (the M4W REST API backing the React prototype in
# priv/static/test) with the same demo content the prototype's
# spaces-data.js / auth-data.js used to hold client-side.
#
#     mix run priv/repo/seeds.exs

alias M4w.Repo

alias M4w.Ops.{
  Artifact,
  ComplianceCheck,
  Contact,
  Decision,
  Item,
  Mail,
  Meeting,
  Org,
  OutboxMessage,
  Passage,
  Room,
  Space,
  User,
  UserSpace,
  Verification
}

defmodule Seed.Helpers do
  alias M4w.Repo
  alias M4w.Ops.{Artifact, Contact, Item, Mail, Passage, Room}

  @now DateTime.utc_now() |> DateTime.truncate(:second)

  def now, do: @now

  def ago(days, hours \\ 0, minutes \\ 0) do
    DateTime.add(@now, -(days * 86_400 + hours * 3_600 + minutes * 60), :second)
  end

  def room!(space, name, position, entity_kind, entity_label, subgoal, key) do
    Repo.insert!(%Room{
      space_id: space.id,
      name: name,
      position: position,
      entity_kind: entity_kind,
      entity_label: entity_label,
      subgoal: subgoal,
      key: key
    })
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

Repo.insert!(%Meeting{
  space_id: styrelse.id,
  title: "Styrelsemöte 12 dec 2025",
  occurred_at: Seed.Helpers.ago(-2),
  status: "planerat",
  location: "Digitalt · Teams",
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
  Seed.Helpers.ago(0, 9, 28), from: r_agenda, to: r_mote, item: it_agenda)

Seed.Helpers.passage!(
  styrelse,
  "Protokoll 14 nov passerade från Möte till Protokoll",
  Seed.Helpers.ago(0, 10, 42), from: r_mote, to: r_protokoll, item: it_protokoll)

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
  Seed.Helpers.ago(1, 7, 38), from: r_protokoll, to: r_beslutslogg)

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

# ================== Space: Projektuppföljning ==================

projekt =
  Repo.insert!(%Space{
    name: "Projektuppföljning",
    address: "projekt-skolappen@m4w.ai",
    category: "Service",
    goal:
      "Håll koll på projektet: fånga beslut, skapa uppgifter med ägare, och följ upp deadlines."
  })

link!.(karin, projekt)
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
  Seed.Helpers.ago(0, 8, 42), from: p_inkorg, to: p_beslut, item: p_it_beslut1)

Seed.Helpers.passage!(
  projekt,
  "Uppgift 'kodgranskning fre' tilldelad Marcus",
  Seed.Helpers.ago(0, 9, 58), item: p_it_uppgift1)

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

link!.(karin, bokforing)
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
  Seed.Helpers.ago(0, 9, 28), from: b_matchning, to: b_godkannande, item: b_it_godkann)

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
  purpose: "context",
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Företagshälsan",
  subject: "Faktura 2024-119 · 8 750 kr",
  at: Seed.Helpers.ago(0, 14, 39),
  purpose: "context",
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "AWS Billing",
  subject: "Invoice 2024-117 · $1,940.00",
  at: Seed.Helpers.ago(1, 1, 10),
  purpose: "context",
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Klarna for Business",
  subject: "Faktura 2024-115 · 1 290 kr",
  at: Seed.Helpers.ago(3),
  purpose: "context",
  use: true
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Marcus (CFO)",
  subject: "Re: ny rutin för avvikelser",
  at: Seed.Helpers.ago(4),
  purpose: "context",
  use: false
})

Seed.Helpers.mail!(bokforing, nil, %{
  from: "Fortnox Support",
  subject: "Re: API-nyckel förnyad",
  at: Seed.Helpers.ago(5),
  purpose: "context",
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
  Seed.Helpers.ago(0, 14, 48), from: f_tidslogg, to: f_fakturering, item: f_it_fakt)

Seed.Helpers.passage!(
  fakturering,
  "Faktura #117 passerade från Fakturering till Uppföljning",
  Seed.Helpers.ago(1, 6, 20), from: f_fakturering, to: f_uppfoljning)

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
