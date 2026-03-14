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
    apiKey: "",
    voice: "af_heart",
    speed: 1.0,
  });

  try {
    const response = await fetch(`${settings.serverUrl}/api/tts`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(settings.apiKey && { "X-API-Key": settings.apiKey }),
      },
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

    const blob = await response.blob();
    const audioUrl = URL.createObjectURL(blob);

    // Send audio to content script for playback
    chrome.tabs.sendMessage(tab.id, {
      type: "kokoro-play",
      audioUrl,
    });
  } catch (err) {
    chrome.tabs.sendMessage(tab.id, {
      type: "kokoro-error",
      message: err.message,
    });
  }
});

// Listen for offscreen audio requests (service workers can't play audio directly)
chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "kokoro-cleanup") {
    if (msg.audioUrl) URL.revokeObjectURL(msg.audioUrl);
  }
});
