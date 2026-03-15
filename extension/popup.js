const $ = (id) => document.getElementById(id);

const defaults = {
  serverUrl: "http://localhost:8787",
  voice: "af_heart",
  speed: 1.0,
  launchAtLogin: false,
};

let nativePort = null;
let serverRunning = false;

// Connect to native host
function connectNative() {
  try {
    nativePort = chrome.runtime.connectNative("com.kokoro.reader");
    nativePort.onMessage.addListener(handleNativeMessage);
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
      // Native host not installed — fall back to HTTP-only status check
      checkServerHTTP();
    });
    // Check status
    nativePort.postMessage({ action: "status" });
  } catch {
    checkServerHTTP();
  }
}

function handleNativeMessage(msg) {
  if (msg.status === "running") {
    setServerStatus(true);
  } else if (msg.status === "stopped") {
    setServerStatus(false);
  } else if (msg.status === "error") {
    $("statusText").textContent = msg.message || "Error";
  }
  $("serverToggle").disabled = false;
}

function setServerStatus(running) {
  serverRunning = running;
  const dot = $("statusDot");
  const text = $("statusText");
  const btn = $("serverToggle");

  dot.className = "dot " + (running ? "running" : "stopped");
  text.textContent = running ? "Server running" : "Server not running";
  btn.textContent = running ? "Stop" : "Start";
  btn.className = "server-btn " + (running ? "stop" : "start");
  btn.disabled = false;

  if (running) {
    chrome.storage.sync.get(defaults, (settings) => {
      fetchVoices(settings.serverUrl, settings.apiKey, settings.voice);
    });
  }
}

async function checkServerHTTP() {
  const settings = await chrome.storage.sync.get(defaults);
  try {
    const res = await fetch(`${settings.serverUrl}/api/health`, { signal: AbortSignal.timeout(3000) });
    if (res.ok) {
      setServerStatus(true);
      return;
    }
  } catch {}
  setServerStatus(false);
}

$("serverToggle").addEventListener("click", () => {
  const btn = $("serverToggle");
  btn.disabled = true;

  const dot = $("statusDot");
  dot.className = "dot checking";
  $("statusText").textContent = serverRunning ? "Stopping..." : "Starting...";

  if (nativePort) {
    nativePort.postMessage({ action: serverRunning ? "stop" : "start" });
  } else {
    // No native host — can't start/stop
    $("statusText").textContent = "Install native host to manage server";
    btn.disabled = false;
    dot.className = "dot stopped";
  }
});

// Load saved settings
chrome.storage.sync.get(defaults, (settings) => {
  $("serverUrl").value = settings.serverUrl;
  $("speed").value = settings.speed;
  $("speedVal").textContent = settings.speed;
  $("launchAtLogin").checked = settings.launchAtLogin;

  fetchVoices(settings.serverUrl, settings.apiKey, settings.voice);
});

$("speed").addEventListener("input", (e) => {
  $("speedVal").textContent = e.target.value;
});

$("save").addEventListener("click", () => {
  const launchAtLogin = $("launchAtLogin").checked;
  const settings = {
    serverUrl: $("serverUrl").value.replace(/\/+$/, ""),
    voice: $("voice").value,
    speed: parseFloat($("speed").value),
    launchAtLogin,
  };

  chrome.storage.sync.set(settings, () => {
    $("status").className = "";
    $("status").textContent = "Saved";
    setTimeout(() => ($("status").textContent = ""), 2000);
  });

  // Update launchd agent via native host
  if (nativePort) {
    nativePort.postMessage({ action: launchAtLogin ? "enable_launch" : "disable_launch" });
  }
});

async function fetchVoices(serverUrl, _unused, selectedVoice) {
  try {
    const res = await fetch(`${serverUrl}/api/voices`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) throw new Error("Failed to fetch voices");

    const data = await res.json();
    const select = $("voice");
    select.innerHTML = "";

    for (const v of data.voices) {
      const opt = document.createElement("option");
      opt.value = v;
      opt.textContent = v;
      if (v === selectedVoice) opt.selected = true;
      select.appendChild(opt);
    }
  } catch {
    // Keep default option if server unreachable
  }
}

// Init
connectNative();
