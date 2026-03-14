const $ = (id) => document.getElementById(id);

const defaults = {
  serverUrl: "http://localhost:8787",
  apiKey: "",
  voice: "af_heart",
  speed: 1.0,
};

// Load saved settings
chrome.storage.sync.get(defaults, (settings) => {
  $("serverUrl").value = settings.serverUrl;
  $("apiKey").value = settings.apiKey;
  $("speed").value = settings.speed;
  $("speedVal").textContent = settings.speed;

  // Fetch voices from server
  fetchVoices(settings.serverUrl, settings.apiKey, settings.voice);
});

$("speed").addEventListener("input", (e) => {
  $("speedVal").textContent = e.target.value;
});

$("save").addEventListener("click", () => {
  const settings = {
    serverUrl: $("serverUrl").value.replace(/\/+$/, ""),
    apiKey: $("apiKey").value,
    voice: $("voice").value,
    speed: parseFloat($("speed").value),
  };

  chrome.storage.sync.set(settings, () => {
    $("status").className = "";
    $("status").textContent = "Saved";
    setTimeout(() => ($("status").textContent = ""), 2000);
  });
});

async function fetchVoices(serverUrl, apiKey, selectedVoice) {
  try {
    const headers = {};
    if (apiKey) headers["X-API-Key"] = apiKey;

    const res = await fetch(`${serverUrl}/api/voices`, { headers });
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
    $("status").className = "error";
    $("status").textContent = "Server unreachable";
  }
}
