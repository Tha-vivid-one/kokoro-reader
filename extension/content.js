// Content script — plays audio and shows toolbar player

let currentAudio = null;
let toolbarEl = null;
let progressInterval = null;
let cachedVoices = null;

function getStyles() {
  return `
    #kokoro-toolbar {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      background: #0a0a14;
      color: #e2e2f0;
      font-family: -apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", sans-serif;
      font-size: 13px;
      z-index: 2147483647;
      border-top: 1px solid rgba(139, 139, 205, 0.15);
      box-shadow: 0 -4px 24px rgba(0, 0, 0, 0.4);
      transition: transform 0.25s ease, opacity 0.2s ease;
      transform: translateY(0);
    }
    #kokoro-toolbar.hidden {
      transform: translateY(100%);
      opacity: 0;
      pointer-events: none;
    }

    /* Progress bar */
    .kokoro-progress-wrap {
      height: 3px;
      background: rgba(139, 139, 205, 0.1);
      cursor: pointer;
      position: relative;
    }
    .kokoro-progress-wrap:hover {
      height: 5px;
    }
    .kokoro-progress-bar {
      height: 100%;
      background: linear-gradient(90deg, #7c7cc9, #a78bfa);
      border-radius: 0 2px 2px 0;
      width: 0%;
      transition: width 0.1s linear;
    }

    /* Main row */
    .kokoro-main {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 16px;
      max-width: 1200px;
      margin: 0 auto;
    }

    /* Transport controls */
    .kokoro-transport {
      display: flex;
      align-items: center;
      gap: 4px;
      flex-shrink: 0;
    }
    .kokoro-btn {
      background: none;
      border: none;
      color: #c8c8e0;
      cursor: pointer;
      padding: 6px;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.15s, color 0.15s;
      line-height: 1;
    }
    .kokoro-btn:hover {
      background: rgba(139, 139, 205, 0.12);
      color: #fff;
    }
    .kokoro-btn.primary {
      background: rgba(139, 139, 205, 0.15);
      width: 36px;
      height: 36px;
    }
    .kokoro-btn.primary:hover {
      background: rgba(139, 139, 205, 0.25);
    }
    .kokoro-btn svg {
      width: 16px;
      height: 16px;
      fill: currentColor;
    }
    .kokoro-btn.primary svg {
      width: 18px;
      height: 18px;
    }

    /* Time */
    .kokoro-time {
      font-size: 11px;
      color: #8888aa;
      font-variant-numeric: tabular-nums;
      flex-shrink: 0;
      min-width: 70px;
    }

    /* Text preview */
    .kokoro-preview {
      flex: 1;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      color: #a0a0c0;
      font-size: 12px;
      padding: 0 8px;
    }

    /* Controls group */
    .kokoro-controls {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }

    /* Voice/Speed selectors */
    .kokoro-select-wrap {
      position: relative;
    }
    .kokoro-select {
      appearance: none;
      background: rgba(139, 139, 205, 0.08);
      border: 1px solid rgba(139, 139, 205, 0.15);
      color: #c8c8e0;
      padding: 4px 24px 4px 8px;
      border-radius: 6px;
      font-size: 12px;
      cursor: pointer;
      font-family: inherit;
      transition: border-color 0.15s;
    }
    .kokoro-select:hover {
      border-color: rgba(139, 139, 205, 0.3);
    }
    .kokoro-select:focus {
      outline: none;
      border-color: #7c7cc9;
      box-shadow: 0 0 0 2px rgba(139, 139, 205, 0.15);
    }
    .kokoro-select-arrow {
      position: absolute;
      right: 6px;
      top: 50%;
      transform: translateY(-50%);
      pointer-events: none;
      color: #6666888;
      font-size: 10px;
    }

    /* Speed display */
    .kokoro-speed-wrap {
      display: flex;
      align-items: center;
      gap: 4px;
    }
    .kokoro-speed-label {
      font-size: 11px;
      color: #8888aa;
    }
    .kokoro-speed-range {
      width: 60px;
      height: 3px;
      accent-color: #7c7cc9;
      cursor: pointer;
    }
    .kokoro-speed-val {
      font-size: 11px;
      color: #a0a0c0;
      min-width: 28px;
      font-variant-numeric: tabular-nums;
    }

    /* Close button */
    .kokoro-close {
      color: #666680;
      padding: 4px;
    }
    .kokoro-close:hover {
      color: #f66;
      background: rgba(255, 100, 100, 0.08);
    }

    /* Loading state */
    .kokoro-loading-text {
      color: #8b8bcd;
      font-size: 12px;
      animation: kokoro-pulse 1.5s ease-in-out infinite;
    }
    @keyframes kokoro-pulse {
      0%, 100% { opacity: 0.5; }
      50% { opacity: 1; }
    }

    /* Branding */
    .kokoro-brand {
      font-size: 11px;
      font-weight: 600;
      color: #8b8bcd;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      flex-shrink: 0;
    }
  `;
}

const icons = {
  play: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>',
  pause: '<svg viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>',
  stop: '<svg viewBox="0 0 24 24"><path d="M6 6h12v12H6z"/></svg>',
  skipBack: '<svg viewBox="0 0 24 24"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg>',
  skipFwd: '<svg viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>',
  close: '<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>',
};

function formatTime(seconds) {
  if (!seconds || !isFinite(seconds)) return "0:00";
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function createToolbar() {
  if (toolbarEl) return toolbarEl;

  toolbarEl = document.createElement("div");
  toolbarEl.id = "kokoro-toolbar";

  const shadow = toolbarEl.attachShadow({ mode: "closed" });

  shadow.innerHTML = `
    <style>${getStyles()}</style>
    <div class="kokoro-progress-wrap" id="progress-wrap">
      <div class="kokoro-progress-bar" id="progress-bar"></div>
    </div>
    <div class="kokoro-main">
      <span class="kokoro-brand">Kokoro</span>

      <div class="kokoro-transport">
        <button class="kokoro-btn" id="skip-back" title="Skip back 10s">${icons.skipBack}</button>
        <button class="kokoro-btn primary" id="play-pause" title="Play/Pause">${icons.play}</button>
        <button class="kokoro-btn" id="skip-fwd" title="Skip forward 10s">${icons.skipFwd}</button>
        <button class="kokoro-btn" id="stop" title="Stop">${icons.stop}</button>
      </div>

      <span class="kokoro-time" id="time">0:00 / 0:00</span>

      <span class="kokoro-preview" id="preview"></span>

      <div class="kokoro-controls">
        <div class="kokoro-select-wrap">
          <select class="kokoro-select" id="voice" title="Voice">
            <option value="af_heart">af_heart</option>
          </select>
          <span class="kokoro-select-arrow">▾</span>
        </div>

        <div class="kokoro-speed-wrap">
          <span class="kokoro-speed-label">Speed</span>
          <input type="range" class="kokoro-speed-range" id="speed" min="0.5" max="2.0" step="0.1" value="1.0">
          <span class="kokoro-speed-val" id="speed-val">1.0x</span>
        </div>

        <button class="kokoro-btn kokoro-close" id="close" title="Close">${icons.close}</button>
      </div>
    </div>
  `;

  // Store shadow root ref for queries
  toolbarEl._shadow = shadow;

  document.body.appendChild(toolbarEl);

  // Wire up events
  const $ = (id) => shadow.getElementById(id);

  $("play-pause").addEventListener("click", () => {
    if (!currentAudio) return;
    if (currentAudio.paused) {
      currentAudio.play();
      $("play-pause").innerHTML = icons.pause;
    } else {
      currentAudio.pause();
      $("play-pause").innerHTML = icons.play;
    }
  });

  $("stop").addEventListener("click", stopAudio);
  $("close").addEventListener("click", stopAudio);

  $("skip-back").addEventListener("click", () => {
    if (!currentAudio) return;
    currentAudio.currentTime = Math.max(0, currentAudio.currentTime - 10);
  });

  $("skip-fwd").addEventListener("click", () => {
    if (!currentAudio) return;
    currentAudio.currentTime = Math.min(currentAudio.duration, currentAudio.currentTime + 10);
  });

  $("progress-wrap").addEventListener("click", (e) => {
    if (!currentAudio || !currentAudio.duration) return;
    const rect = $("progress-wrap").getBoundingClientRect();
    const fraction = (e.clientX - rect.left) / rect.width;
    currentAudio.currentTime = fraction * currentAudio.duration;
  });

  $("speed").addEventListener("input", (e) => {
    const val = parseFloat(e.target.value);
    $("speed-val").textContent = val.toFixed(1) + "x";
    if (currentAudio) currentAudio.playbackRate = val;
    chrome.storage.sync.set({ speed: val });
  });

  $("voice").addEventListener("change", (e) => {
    chrome.storage.sync.set({ voice: e.target.value });
  });

  // Load saved settings
  chrome.storage.sync.get({ voice: "af_heart", speed: 1.0 }, (settings) => {
    $("speed").value = settings.speed;
    $("speed-val").textContent = settings.speed.toFixed(1) + "x";
    loadVoices(settings.voice);
  });

  return toolbarEl;
}

async function loadVoices(selectedVoice) {
  if (!toolbarEl?._shadow) return;
  const select = toolbarEl._shadow.getElementById("voice");

  if (cachedVoices) {
    populateVoices(select, cachedVoices, selectedVoice);
    return;
  }

  try {
    const settings = await chrome.storage.sync.get({ serverUrl: "http://localhost:8787" });
    const res = await fetch(`${settings.serverUrl}/api/voices`, { signal: AbortSignal.timeout(3000) });
    if (res.ok) {
      const data = await res.json();
      cachedVoices = data.voices;
      populateVoices(select, cachedVoices, selectedVoice);
    }
  } catch {
    // Keep default
  }
}

function populateVoices(select, voices, selectedVoice) {
  select.innerHTML = "";
  for (const v of voices) {
    const opt = document.createElement("option");
    opt.value = v;
    opt.textContent = v;
    if (v === selectedVoice) opt.selected = true;
    select.appendChild(opt);
  }
}

function startProgressUpdates() {
  stopProgressUpdates();
  progressInterval = setInterval(() => {
    if (!currentAudio || !toolbarEl?._shadow) return;
    const bar = toolbarEl._shadow.getElementById("progress-bar");
    const time = toolbarEl._shadow.getElementById("time");
    if (currentAudio.duration) {
      const pct = (currentAudio.currentTime / currentAudio.duration) * 100;
      bar.style.width = pct + "%";
      time.textContent = `${formatTime(currentAudio.currentTime)} / ${formatTime(currentAudio.duration)}`;
    }
  }, 100);
}

function stopProgressUpdates() {
  if (progressInterval) {
    clearInterval(progressInterval);
    progressInterval = null;
  }
}

function setToolbarState(state, previewText) {
  if (!toolbarEl?._shadow) return;
  const $ = (id) => toolbarEl._shadow.getElementById(id);

  if (state === "loading") {
    $("play-pause").innerHTML = icons.pause;
    $("play-pause").disabled = true;
    $("preview").innerHTML = '<span class="kokoro-loading-text">Generating audio...</span>';
    $("time").textContent = "—:——";
    $("progress-bar").style.width = "0%";
  } else if (state === "playing") {
    $("play-pause").innerHTML = icons.pause;
    $("play-pause").disabled = false;
    if (previewText) {
      $("preview").textContent = previewText.slice(0, 120);
    }
  }
}

function stopAudio() {
  stopProgressUpdates();
  if (currentAudio) {
    currentAudio.pause();
    currentAudio = null;
  }
  removeToolbar();
}

function removeToolbar() {
  if (toolbarEl) {
    toolbarEl.classList.add("hidden");
    setTimeout(() => {
      toolbarEl?.remove();
      toolbarEl = null;
    }, 250);
  }
}

function showError(message) {
  const el = document.createElement("div");
  el.style.cssText = `
    position: fixed; bottom: 20px; right: 20px;
    background: #1a0a0a; color: #f88; border-radius: 8px;
    padding: 10px 16px; font-family: -apple-system, sans-serif;
    font-size: 13px; box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    border: 1px solid rgba(255,100,100,0.15);
    z-index: 2147483647;
  `;
  el.textContent = `Kokoro: ${message}`;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "kokoro-loading") {
    stopAudio();
    createToolbar();
    setToolbarState("loading");
    return;
  }

  if (msg.type === "kokoro-play") {
    if (!toolbarEl) createToolbar();
    stopProgressUpdates();
    if (currentAudio) {
      currentAudio.pause();
      currentAudio = null;
    }

    setToolbarState("playing", msg.previewText);

    currentAudio = new Audio(msg.audioUrl);

    // Apply saved speed
    chrome.storage.sync.get({ speed: 1.0 }, (settings) => {
      if (currentAudio) currentAudio.playbackRate = settings.speed;
    });

    currentAudio.addEventListener("ended", () => {
      stopProgressUpdates();
      removeToolbar();
      currentAudio = null;
    });
    currentAudio.addEventListener("error", () => {
      showError("Audio playback failed");
      stopAudio();
    });
    currentAudio.play();
    startProgressUpdates();
  }

  if (msg.type === "kokoro-error") {
    stopAudio();
    showError(msg.message);
  }
});
