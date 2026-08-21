const menuButton = document.querySelector("[data-menu-toggle]");
const menu = document.querySelector("[data-menu]");

if (menuButton && menu) {
  menuButton.addEventListener("click", () => {
    const open = menu.classList.toggle("is-open");
    menuButton.setAttribute("aria-expanded", String(open));
  });

  menu.addEventListener("click", (event) => {
    if (event.target.closest("a")) {
      menu.classList.remove("is-open");
      menuButton.setAttribute("aria-expanded", "false");
    }
  });
}

const year = document.querySelector("[data-current-year]");
if (year) year.textContent = new Date().getFullYear();

const params = new URLSearchParams(window.location.search);
const invitationCode = (params.get("join") || "").trim().toUpperCase();
const invitation = document.querySelector("[data-invitation]");

if (invitation && /^[A-Z0-9]{1,12}$/.test(invitationCode)) {
  invitation.hidden = false;
  invitation.querySelector("[data-invitation-code]").textContent = invitationCode;
  invitation.querySelector("[data-open-app]").href = `mosaic://join/${encodeURIComponent(invitationCode)}`;
  document.title = `Join ${invitationCode} in Mosaic`;
}
