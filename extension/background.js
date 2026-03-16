// Service worker — context menu + TTS API calls

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "kokoro-read",
    title: "Read aloud with Kokoro",
    contexts: ["selection"],
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== "kokoro-read" || !info.selectionText) return;

  const text = info.selectionText.trim();
  if (!text) return;

  const settings = await chrome.storage.sync.get({
    serverUrl: "http://localhost:8787",
    voice: "af_heart",
    speed: 1.0,
  });

  try {
    // Notify content script we're loading
    chrome.tabs.sendMessage(tab.id, { type: "kokoro-loading" }).catch(() => {
      // Content script not injected — inject it first
      chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ["content.js"],
      });
      // Retry after injection
      setTimeout(() => {
        chrome.tabs.sendMessage(tab.id, { type: "kokoro-loading" }).catch(() => {});
      }, 200);
    });

    // TTS request — no timeout so long text can process
    const response = await fetch(`${settings.serverUrl}/api/tts`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text: text.slice(0, 5000),
        voice: settings.voice,
        speed: settings.speed,
      }),
    });

    if (!response.ok) {
      const err = await response.json().catch(() => ({ detail: response.statusText }));
      throw new Error(err.detail || "TTS request failed");
    }

    const buffer = await response.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    let binary = "";
    for (let i = 0; i < bytes.length; i += 8192) {
      binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
    }
    const audioUrl = `data:audio/wav;base64,${btoa(binary)}`;

    chrome.tabs.sendMessage(tab.id, {
      type: "kokoro-play",
      audioUrl,
      previewText: text.slice(0, 120),
    });
  } catch (err) {
    chrome.tabs.sendMessage(tab.id, {
      type: "kokoro-error",
      message: err.message,
    }).catch(() => {});
  }
});
