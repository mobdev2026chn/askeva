/* =========================================================
   AskEva — Shared chart color system (single source of truth)
   Use window.CHART everywhere a graph is drawn so bars share
   one color and other charts share one consistent palette.
   ========================================================= */
(function () {
  window.CHART = {
    /* every BAR graph uses this one brand-green fill */
    bar:      "#2BA84A",   // brand-600
    barSoft:  "#CDEAC4",   // light green for the secondary/“open” segment
    barTrack: "#EAF9E6",   // empty-bar track

    /* shared axis / grid styling */
    grid:     "#EEF1EC",

    /* categorical palette for multi-series charts (lines, donuts, stacks) */
    series: ["#2BA84A", "#2563EB", "#F59E0B", "#F87171", "#8B5CF6", "#5AB6E8", "#EAB308"],

    /* on-brand GREEN SHADE scale — a clean light→dark ramp so stacked status
       segments stay green-branded but are each clearly distinguishable
       (instead of near-identical greens that blend into one block). */
    statusScale: {
      assigned:   "#17813A",  // deepest (base of stack)
      inprogress: "#25A046",
      awaiting:   "#3CC23F",
      pending:    "#5FC94B",
      reopened:   "#85D653",
      completed:  "#B6EC93",  // lightest (top of stack)
      total:      "#16762F"
    },

    /* semantic status colors (kept in step with CLAUDE.md) */
    status: {
      assigned:   "#2BA84A",
      inprogress: "#F59E0B",
      awaiting:   "#F87171",
      pending:    "#EAB308",
      completed:  "#3CC23F",
      reopened:   "#8B5CF6",
      total:      "#2BA84A"
    }
  };
})();
