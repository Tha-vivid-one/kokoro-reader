// Content script — plays audio and shows floating player

let currentAudio = null;
let playerEl = null;

function createPlayer() {
  if (playerEl) return playerEl;

  playerEl = document.createElement("div");
  playerEl.id = "kokoro-player";
  playerEl.innerHTML = `
    <style>
      #kokoro-player {
        position: fixed;
        bottom: 20px;
        right: 20px;
        background: #1a1a2e;
        color: #eee;
        border-radius: 12px;
        padding: 10px 16px;
        display: flex;
        align-items: center;
        gap: 10px;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        font-size: 13px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        z-index: 2147483647;
        transition: opacity 0.2s;
      }
      #kokoro-player button {
        background: none;
        border: none;
        color: #eee;
        cursor: pointer;
        font-size: 16px;
        padding: 2px 6px;
        border-radius: 4px;
      }
      #kokoro-player button:hover {
        background: rgba(255,255,255,0.1);
      }
      #kokoro-player .kokoro-label {
        color: #8b8bcd;
        font-weight: 500;
      }
    </style>
    <span class="kokoro-label">Kokoro</span>
    <button id="kokoro-pause" title="Pause/Resume">&#9646;&#9646;</button>
    <button id="kokoro-stop" title="Stop">&#9632;</button>
  `;

  document.body.appendChild(playerEl);

  playerEl.querySelector("#kokoro-pause").addEventListener("click", () => {
    if (!currentAudio) return;
    if (currentAudio.paused) {
      currentAudio.play();
      playerEl.querySelector("#kokoro-pause").innerHTML = "&#9646;&#9646;";
    } else {
      currentAudio.pause();
      playerEl.querySelector("#kokoro-pause").innerHTML = "&#9654;";
    }
  });

  playerEl.querySelector("#kokoro-stop").addEventListener("click", () => {
    stopAudio();
  });

  return playerEl;
}

function stopAudio() {
  if (currentAudio) {
    const url = currentAudio.src;
    currentAudio.pause();
    currentAudio = null;
    chrome.runtime.sendMessage({ type: "kokoro-cleanup", audioUrl: url });
  }
  removePlayer();
}

function removePlayer() {
  if (playerEl) {
    playerEl.remove();
    playerEl = null;
  }
}

function showError(message) {
  const el = document.createElement("div");
  el.style.cssText = `
    position: fixed; bottom: 20px; right: 20px;
    background: #2d1b1b; color: #f88; border-radius: 12px;
    padding: 10px 16px; font-family: -apple-system, sans-serif;
    font-size: 13px; box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    z-index: 2147483647;
  `;
  el.textContent = `Kokoro: ${message}`;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "kokoro-play") {
    // Stop any existing playback
    stopAudio();

    createPlayer();
    currentAudio = new Audio(msg.audioUrl);
    currentAudio.addEventListener("ended", () => {
      chrome.runtime.sendMessage({ type: "kokoro-cleanup", audioUrl: msg.audioUrl });
      removePlayer();
      currentAudio = null;
    });
    currentAudio.addEventListener("error", () => {
      showError("Audio playback failed");
      removePlayer();
      currentAudio = null;
    });
    currentAudio.play();
  }

  if (msg.type === "kokoro-error") {
    showError(msg.message);
  }
});
