/* Move Account Details + Team Members drill-ins from Settings to Profile. */
(function () {
  var prof = document.getElementById("app-profile");
  if (!prof) return;
  ["sub-account", "sub-team"].forEach(function (id) {
    var el = document.getElementById(id);
    if (el && el.parentNode !== prof) prof.appendChild(el);  // relocate; existing listeners persist
  });
  // wire the Profile entry rows to open the relocated sub-views
  Array.prototype.slice.call(prof.querySelectorAll(".pf-accrow[data-sub]")).forEach(function (row) {
    row.addEventListener("click", function () {
      var el = document.getElementById("sub-" + row.getAttribute("data-sub"));
      if (el) { el.classList.add("show"); var sc = el.querySelector(".set-scroll"); if (sc) sc.scrollTop = 0; }
    });
  });
})();
