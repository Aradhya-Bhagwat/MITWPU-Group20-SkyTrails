// Replace this value with the public Apple invite once the TestFlight group is live.
const TESTFLIGHT_URL = "";

const header = document.querySelector("#site-header");
const menuButton = document.querySelector("#menu-button");
const siteNav = document.querySelector("#site-nav");
const themeToggle = document.querySelector("#theme-toggle");
const testFlightLinks = document.querySelectorAll(".testflight-link");
const betaNote = document.querySelector("#beta-note");
const themeColor = document.querySelector('meta[name="theme-color"]');

function updateHeader() {
  header.classList.toggle("scrolled", window.scrollY > 20);
}

function closeMenu() {
  menuButton.setAttribute("aria-expanded", "false");
  menuButton.setAttribute("aria-label", "Open navigation");
  siteNav.classList.remove("open");
  document.body.classList.remove("menu-open");
}

menuButton.addEventListener("click", () => {
  const isOpen = menuButton.getAttribute("aria-expanded") === "true";
  menuButton.setAttribute("aria-expanded", String(!isOpen));
  menuButton.setAttribute("aria-label", isOpen ? "Open navigation" : "Close navigation");
  siteNav.classList.toggle("open", !isOpen);
  document.body.classList.toggle("menu-open", !isOpen);
});

siteNav.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", closeMenu);
});

testFlightLinks.forEach((link) => {
  if (TESTFLIGHT_URL) {
    link.href = TESTFLIGHT_URL;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
  } else {
    link.href = "#beta";
  }
});

if (TESTFLIGHT_URL) {
  betaNote.textContent = "TestFlight will open in a new tab. Apple may ask you to install the free TestFlight app before joining the SkyTrails beta.";
}

function applyTheme(theme) {
  const isDark = theme === "dark";
  document.documentElement.dataset.theme = theme;
  themeToggle.setAttribute("aria-pressed", String(isDark));
  themeToggle.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");
  themeColor.setAttribute("content", isDark ? "#0b1512" : "#f7faf8");
}

themeToggle.addEventListener("click", () => {
  const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  localStorage.setItem("skytrails-theme", nextTheme);
  applyTheme(nextTheme);
});

let identifyInterval;
const screenDots = document.querySelectorAll(".screen-dot");

function switchIdentifyImage(button) {
  const image = document.querySelector("#identify-image");
  if (!image || !button) return;

  screenDots.forEach((dot) => dot.classList.remove("active"));
  button.classList.add("active");
  image.style.opacity = "0";

  window.setTimeout(() => {
    image.src = button.dataset.image;
    image.alt = button.dataset.alt;
    image.style.opacity = "1";
  }, 160);
}

function startIdentifySlideshow() {
  stopIdentifySlideshow();
  identifyInterval = window.setInterval(() => {
    let activeIndex = Array.from(screenDots).findIndex(dot => dot.classList.contains("active"));
    let nextIndex = (activeIndex + 1) % screenDots.length;
    switchIdentifyImage(screenDots[nextIndex]);
  }, 4000);
}

function stopIdentifySlideshow() {
  if (identifyInterval) clearInterval(identifyInterval);
}

screenDots.forEach((button) => {
  button.addEventListener("click", () => {
    switchIdentifyImage(button);
    startIdentifySlideshow();
  });
});

startIdentifySlideshow();

const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add("visible");
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12 });

document.querySelectorAll(".reveal").forEach((element) => revealObserver.observe(element));
window.addEventListener("scroll", updateHeader, { passive: true });
window.addEventListener("resize", () => {
  if (window.innerWidth > 760) closeMenu();
});
updateHeader();
applyTheme(document.documentElement.dataset.theme);
