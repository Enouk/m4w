// Demo users for the login prototype.
// Two colleagues share "Acme AB" (with different Space access — Marcus
// isn't on the board, so he doesn't see Styrelsearbete). Sara is a
// standalone enskild firma with her own single Space — no org, no sharing.

const USERS = {
  karin: {
    id: "karin",
    name: "Karin Lindqvist",
    email: "karin.lindqvist@acme.se",
    role: "Styrelseordförande",
    org: "Acme AB",
    initials: "KL",
    spaces: ["styrelse", "projekt", "bokforing"]
  },
  marcus: {
    id: "marcus",
    name: "Marcus Nilsson",
    email: "marcus@acme.se",
    role: "Ekonomiansvarig · CFO",
    org: "Acme AB",
    initials: "MN",
    spaces: ["projekt", "bokforing"]
  },
  sara: {
    id: "sara",
    name: "Sara Ahlén",
    email: "sara@ahlenkonsult.se",
    role: "Enskild firma",
    org: null,
    initials: "SA",
    spaces: ["fakturering"]
  }
};

window.USERS = USERS;
