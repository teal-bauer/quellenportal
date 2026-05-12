// Global keyboard shortcuts + sticky-header scroll shadow.

const isMac = /Mac|iPhone|iPad/.test(navigator.platform);

document.addEventListener("DOMContentLoaded", () => {
  const target = document.querySelector("[data-shortcut-affordance]");
  if (target) {
    target.textContent = isMac ? "⌘K" : "Ctrl K";
  }

  const header = document.querySelector("[data-site-header]");
  if (header) {
    const updateShadow = () => {
      header.classList.toggle("is-scrolled", window.scrollY > 4);
    };
    updateShadow();
    document.addEventListener("scroll", updateShadow, { passive: true });
  }
});

document.addEventListener("keydown", (event) => {
  const input = document.querySelector("[data-search-input]");
  if (!input) return;

  const active = document.activeElement;
  const typing = active && (active.tagName === "INPUT" || active.tagName === "TEXTAREA" || active.isContentEditable);

  const isCmdK = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k";
  const isSlash = event.key === "/" && !typing;

  if (isCmdK || isSlash) {
    event.preventDefault();
    input.focus();
    input.select();
  }

  if (event.key === "Escape" && active === input) {
    input.blur();
  }
});
