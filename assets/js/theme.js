export const THEME_STORAGE_KEY = "hermes-trictrac:theme";

export const THEME_OPTIONS = [
  { id: "solarized-light", labelKey: "themes.solarizedLight" },
  { id: "warm", labelKey: "themes.warm" },
  { id: "solarized-dark", labelKey: "themes.solarizedDark" }
];

const SUPPORTED = new Set(THEME_OPTIONS.map((option) => option.id));
const THEME_EVENT = "hermes-trictrac:theme-change";

let currentTheme = resolveInitialTheme();
applyDocumentTheme(currentTheme);

export function normalizeTheme(value) {
  const normalized = String(value || "").trim().toLowerCase();
  return SUPPORTED.has(normalized) ? normalized : "solarized-light";
}

export function themeColorScheme(theme = currentTheme) {
  return normalizeTheme(theme) === "solarized-light" ? "light" : "dark";
}

export function resolveInitialTheme() {
  if (typeof document !== "undefined") {
    const documentTheme = document.documentElement?.dataset?.theme;

    if (documentTheme) {
      return normalizeTheme(documentTheme);
    }
  }

  try {
    return normalizeTheme(window.localStorage.getItem(THEME_STORAGE_KEY));
  } catch (_error) {
    return "solarized-light";
  }
}

export function getTheme() {
  return currentTheme;
}

export function nextTheme(theme = currentTheme) {
  const normalized = normalizeTheme(theme);
  const index = THEME_OPTIONS.findIndex((option) => option.id === normalized);
  const nextIndex = index >= 0 ? (index + 1) % THEME_OPTIONS.length : 0;
  return THEME_OPTIONS[nextIndex].id;
}

export function applyDocumentTheme(theme = currentTheme) {
  const next = normalizeTheme(theme);

  if (typeof document !== "undefined") {
    document.documentElement.dataset.theme = next;
    document.documentElement.style.colorScheme = themeColorScheme(next);
  }

  return next;
}

export function setTheme(theme) {
  const next = normalizeTheme(theme);
  currentTheme = next;
  applyDocumentTheme(next);

  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, next);
  } catch (_error) {
    // Theme persistence is nice to have, not required for play.
  }

  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent(THEME_EVENT, { detail: { theme: next } }));
  }

  return next;
}

export function cycleTheme(theme = currentTheme) {
  return setTheme(nextTheme(theme));
}

export function subscribeTheme(callback) {
  const handler = (event) => callback(event.detail.theme);
  window.addEventListener(THEME_EVENT, handler);
  return () => window.removeEventListener(THEME_EVENT, handler);
}

export function syncThemeControls(root = document) {
  root.querySelectorAll("[data-theme-select]").forEach((select) => {
    select.value = currentTheme;
  });

  root.querySelectorAll("[data-theme-cycle]").forEach((button) => {
    button.dataset.themeCurrent = currentTheme;
    button.dataset.themeNext = nextTheme(currentTheme);
  });
}

export function attachThemeControls(root = document) {
  syncThemeControls(root);

  root.querySelectorAll("[data-theme-select]").forEach((select) => {
    select.addEventListener("change", (event) => {
      setTheme(event.target.value);
      syncThemeControls(root);
    });
  });

  root.querySelectorAll("[data-theme-cycle]").forEach((button) => {
    button.addEventListener("click", () => {
      cycleTheme();
      syncThemeControls(root);
    });
  });
}

export function themeSelectOptions() {
  return THEME_OPTIONS;
}
