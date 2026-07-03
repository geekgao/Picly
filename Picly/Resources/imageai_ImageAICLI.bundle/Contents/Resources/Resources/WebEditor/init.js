(function () {
  "use strict";

  function getParams() {
    const p = new URLSearchParams(window.location.search);
    return {
      path: p.get("path") || "",
      save: p.get("save") || "overwrite",
      embedded: p.get("embedded") || "",
    };
  }

  async function loadImage(path) {
    if (!path) return null;
    const resp = await fetch(
      "/api/v1/image-file?path=" + encodeURIComponent(path)
    );
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({ error: resp.statusText }));
      throw new Error(err.error || "加载图片失败");
    }
    const blob = await resp.blob();
    return URL.createObjectURL(blob);
  }

  function getImageFileName(path) {
    if (!path) return "untitled";
    const parts = path.replace(/\\/g, "/").split("/");
    return parts[parts.length - 1] || "untitled";
  }

  function getImageDir(path) {
    if (!path) return "";
    const idx = path.lastIndexOf("/");
    if (idx === -1) return "";
    return path.substring(0, idx);
  }

  async function saveImage(path, base64, mode) {
    const resp = await fetch("/api/v1/image-file", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: path, data: base64, mode: mode }),
    });
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({ error: resp.statusText }));
      throw new Error(err.error || "保存失败");
    }
    return await resp.json();
  }

  window.__imageaiSavePicked = function (path) {
    var cb = window.__imageaiSaveCallback;
    window.__imageaiSaveCallback = null;
    if (!cb) return;
    cb(path || null);
  };

  function hideLoading() {
    const el = document.getElementById("loading");
    if (el) el.style.display = "none";
  }

  var _pendingFileCallback = null;

  window.__imageaiFilePicked = async function (path, name) {
    var annotateCb = window.__imageaiAnnotateImageCallback;
    if (annotateCb) {
      window.__imageaiAnnotateImageCallback = null;
      if (!path) return;
      try {
        var blobUrl = await loadImage(path);
        var img = new Image();
        img.onload = function () { annotateCb(img); URL.revokeObjectURL(blobUrl); };
        img.onerror = function () { alert("加载图片失败"); };
        img.src = blobUrl;
      } catch (e) {
        alert("加载图片失败: " + e.message);
      }
      return;
    }

    var wmCb = window.__imageaiWatermarkCallback;
    if (wmCb) {
      window.__imageaiWatermarkCallback = null;
      if (!path) return;
      try {
        var blobUrl = await loadImage(path);
        wmCb(blobUrl);
      } catch (e) {
        alert("加载水印图片失败: " + e.message);
      }
      return;
    }

    var overlay = document.getElementById("open-dialog");
    if (overlay) overlay.remove();
    var cb = _pendingFileCallback;
    _pendingFileCallback = null;
    if (!path || !cb) return;
    try {
      var blobUrl = await loadImage(path);
      cb({ url: blobUrl, path: path });
    } catch (e) {
      alert("加载图片失败: " + e.message);
    }
  };

  async function pasteFromClipboard() {
    try {
      if (!navigator.clipboard || !navigator.clipboard.read) {
        alert("当前浏览器不支持读取剪贴板");
        return null;
      }
      var items = await navigator.clipboard.read();
      for (var item of items) {
        for (var type of item.types) {
          if (type.startsWith("image/")) {
            var blob = await item.getType(type);
            return { url: URL.createObjectURL(blob), path: "clipboard." + type.split("/").pop() };
          }
        }
      }
      alert("剪贴板中没有图片");
      return null;
    } catch (e) {
      alert("读取剪贴板失败: " + e.message);
      return null;
    }
  }

  function showOpenDialog(onPicked) {
    _pendingFileCallback = onPicked;

    var overlay = document.createElement("div");
    overlay.id = "open-dialog";
    overlay.style.cssText =
      "position:fixed;inset:0;background:#1a1a2e;display:flex;align-items:center;justify-content:center;flex-direction:column;z-index:99999;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#fff;";

    var title = document.createElement("h2");
    title.textContent = "ImageAI 图片编辑器";
    title.style.cssText = "font-weight:400;font-size:20px;margin-bottom:8px;color:#fff;";
    overlay.appendChild(title);

    var subtitle = document.createElement("p");
    subtitle.textContent = "选择一张图片开始编辑";
    subtitle.style.cssText = "font-size:13px;color:#999;margin-bottom:32px;";
    overlay.appendChild(subtitle);

    var btn = document.createElement("button");
    btn.textContent = "从本地选择图片";
    btn.style.cssText = "display:block;width:220px;padding:12px 28px;margin-bottom:10px;border:none;border-radius:8px;background:#0076FA;color:#fff;font-size:15px;cursor:pointer;";
    overlay.appendChild(btn);

    var btnPaste = document.createElement("button");
    btnPaste.textContent = "从剪贴板粘贴  ⌘V";
    btnPaste.style.cssText = "display:block;width:220px;padding:12px 28px;border:1px solid rgba(255,255,255,0.3);border-radius:8px;background:transparent;color:#fff;font-size:15px;cursor:pointer;";
    overlay.appendChild(btnPaste);

    document.body.appendChild(overlay);

    btn.onclick = function () {
      if (window.webkit && window.webkit.messageHandlers) {
        window.webkit.messageHandlers.openFileDialog.postMessage("");
      } else {
        var input = document.createElement("input");
        input.type = "file";
        input.accept = "image/*";
        input.onchange = function () {
          var file = input.files[0];
          if (!file) return;
          overlay.remove();
          onPicked({ url: URL.createObjectURL(file), path: file.name });
        };
        input.click();
      }
    };

    btnPaste.onclick = async function () {
      var result = await pasteFromClipboard();
      if (result) {
        overlay.remove();
        onPicked(result);
      }
    };

    window.__imageaiPasteCallback = function (result) {
      window.__imageaiPasteCallback = null;
      overlay.remove();
      onPicked(result);
    };
  }

  async function init() {
    const params = getParams();
    const { TABS, TOOLS } = window.FilerobotImageEditor || {};
    const container = document.getElementById("editor_container");

    if (!window.FilerobotImageEditor) {
      document.getElementById("loading").querySelector("p").textContent =
        "编辑器加载失败，请检查网络";
      return;
    }

    let sourceUrl = null;
    let imagePath = params.path;

    if (imagePath) {
      try {
        sourceUrl = await loadImage(imagePath);
      } catch (e) {
        document.getElementById("loading").querySelector("p").textContent =
          "图片加载失败: " + e.message;
        return;
      }
    }

    const macOSTheme = {
      palette: {
        'bg-primary': '#F9F9F9',
        'bg-secondary': '#FFFFFF',
        'bg-primary-active': '#EFEFEF',
        'bg-hover': '#F0F0F0',
        'bg-stateless': '#F5F5F5',
        'accent-primary': '#0076FA',
        'accent-primary-active': '#005CC8',
        'accent-primary-hover': '#0068E0',
        'accent-stateless': '#0076FA',
        'icons-primary': '#333333',
        'icons-secondary': '#666666',
        'icons-muted': '#999999',
        'icons-placeholder': '#BBBBBB',
        'txt-primary': '#333333',
        'txt-secondary': '#666666',
        'txt-placeholder': '#999999',
        'borders-primary': '#D1D1D1',
        'borders-secondary': '#E5E5E5',
        'borders-strong': '#AAAAAA',
        'borders-item': '#D1D1D1',
        'border-primary-stateless': '#D1D1D1',
        'light-shadow': 'rgba(0,0,0,0.06)',
        'warning': '#E53D3D',
        'error': '#E53D3D',
        'success': '#34C759',
      },
      typography: {
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Arial, sans-serif',
      },
    };

    const config = {
      source: sourceUrl || "",
      theme: macOSTheme,
      defaultSavedImageName: getImageFileName(imagePath) || "edited_image",
      defaultSavedImageType: "jpeg",
      closeAfterSave: false,
      avoidChangesNotSavedAlertOnLeave: true,
      showBackButton: true,
      'Watermark': {
        onUploadWatermarkImgClick: function(loadAndSetWatermarkImg) {
          if (window.webkit && window.webkit.messageHandlers) {
            window.__imageaiWatermarkCallback = loadAndSetWatermarkImg;
            window.webkit.messageHandlers.openFileDialog.postMessage("");
          } else {
            var input = document.createElement("input");
            input.type = "file";
            input.accept = "image/*";
            input.onchange = function () {
              var file = input.files[0];
              if (!file) return;
              loadAndSetWatermarkImg(URL.createObjectURL(file), true);
            };
            input.click();
          }
        },
      },
      'Image': {
        onUploadImageClick: function(addImgScaled) {
          if (window.webkit && window.webkit.messageHandlers) {
            window.__imageaiAnnotateImageCallback = addImgScaled;
            window.webkit.messageHandlers.openFileDialog.postMessage("");
          } else {
            var input = document.createElement("input");
            input.type = "file";
            input.accept = "image/*";
            input.onchange = function () {
              var file = input.files[0];
              if (!file) return;
              var img = new Image();
              img.onload = function () { addImgScaled(img); };
              img.src = URL.createObjectURL(file);
            };
            input.click();
          }
        },
      },
      tabsIds: [TABS.ADJUST, TABS.FINETUNE, TABS.FILTERS, TABS.WATERMARK, TABS.ANNOTATE, TABS.RESIZE],
      onSave: async (editedImageObject) => {
        const dataUrl = editedImageObject.imageBase64 || editedImageObject.fullImageBase64;
        if (!dataUrl) return;

        try {
          const defaultName = getImageFileName(imagePath) || "edited_image";

          if (params.embedded && window.webkit && window.webkit.messageHandlers) {
            const savePath = await new Promise(function (resolve) {
              window.__imageaiSaveCallback = resolve;
              window.webkit.messageHandlers.saveFileDialog.postMessage(defaultName);
            });
            if (savePath) {
              await saveImage(savePath, dataUrl, "save-as");
              window.webkit.messageHandlers.closeEditor.postMessage("");
            }
            return;
          }

          if (params.save === "overwrite" && imagePath) {
            await saveImage(imagePath, dataUrl, "overwrite");
            return;
          }

          const dot = defaultName.lastIndexOf(".");
          const base = dot > 0 ? defaultName.substring(0, dot) : defaultName;
          const ext = dot > 0 ? defaultName.substring(dot) : ".png";
          const defaultSave = base + "_edited" + ext;

          if (window.webkit && window.webkit.messageHandlers) {
            const savePath = await new Promise(function (resolve) {
              window.__imageaiSaveCallback = resolve;
              window.webkit.messageHandlers.saveFileDialog.postMessage(defaultSave);
            });
            if (savePath) {
              await saveImage(savePath, dataUrl, "save-as");
            }
          } else {
            var a = document.createElement("a");
            a.href = dataUrl;
            a.download = defaultSave;
            a.click();
          }
        } catch (e) {
          alert("保存失败: " + e.message);
        }
      },
    };

    if (!sourceUrl) {
      hideLoading();
      var pickResult = await waitForFilePick();
      sourceUrl = pickResult.url;
      imagePath = pickResult.path;
    }
    config.source = sourceUrl;

    window.__imageaiReloadEditor = function (newUrl, newPath) {
      if (window.__imageaiCurrentEditor) {
        window.__imageaiCurrentEditor.terminate();
      }
      sourceUrl = newUrl;
      imagePath = newPath;
      config.source = sourceUrl;
      var newEditor = new window.FilerobotImageEditor(container, config);
      newEditor.render({ onClose: makeOnClose() });
      window.__imageaiCurrentEditor = newEditor;
    };

  window.__imageaiClipboardPicked = function (path, name) {
    try {
      if (!path) return;
      var dialog = document.getElementById("open-dialog");
      if (dialog) {
        dialog.remove();
        var cb = window.__imageaiPasteCallback;
        window.__imageaiPasteCallback = null;
        var x = new XMLHttpRequest();
        x.open("GET", "/api/v1/image-file?path=" + encodeURIComponent(path), true);
        x.responseType = "blob";
        x.onload = function () {
          if (x.status !== 200) { alert("粘贴失败: " + x.statusText); return; }
          var url = URL.createObjectURL(x.response);
          if (cb) cb({ url: url, path: path });
        };
        x.onerror = function () { alert("粘贴失败: 网络错误"); };
        x.send();
      } else {
        var event = new CustomEvent("imageai:paste-image", { detail: path });
        document.dispatchEvent(event);
      }
    } catch (e) { alert("粘贴失败: " + e.message); }
  };

    function makeOnClose() {
      return async function () {
        if (params.embedded && window.webkit && window.webkit.messageHandlers) {
          window.webkit.messageHandlers.closeEditor.postMessage("");
          return;
        }
        if (window.__imageaiCurrentEditor) {
          window.__imageaiCurrentEditor.terminate();
        }
        var result = await waitForFilePick();
        if (!result) return;
        window.__imageaiReloadEditor(result.url, result.path);
      };
    }

    var editor = new window.FilerobotImageEditor(container, config);
    window.__imageaiCurrentEditor = editor;
    editor.render({ onClose: makeOnClose() });

    hideLoading();

    async function waitForFilePick() {
      return new Promise(function (resolve) {
        showOpenDialog(function (picked) {
          if (!picked || !picked.url) return;
          resolve({ url: picked.url, path: picked.path });
        });
      });
    }
  }

  document.addEventListener("contextmenu", function (e) {
    var tag = e.target.tagName;
    if (tag !== "INPUT" && tag !== "TEXTAREA" && !e.target.closest("[contenteditable]")) {
      e.preventDefault();
    }
  });

  document.addEventListener("keydown", function (e) {
    if (!window.webkit || !window.webkit.messageHandlers) return;
    var isCmd = e.metaKey || e.ctrlKey;

    if (isCmd && e.key === "v") {
      e.preventDefault();
      e.stopPropagation();
      window.webkit.messageHandlers.readClipboard.postMessage("");
      return;
    }

    if (isCmd && e.key === "c") {
      e.preventDefault();
      e.stopPropagation();
      try {
        var ed = window.__imageaiCurrentEditor;
        if (!ed || typeof ed.getCurrentImgData !== "function") return;
        var d = ed.getCurrentImgData({ name: "image", extension: "png" }, 1, true);
        if (d && d.imageData && d.imageData.imageBase64) {
          window.webkit.messageHandlers.writeClipboard.postMessage(d.imageData.imageBase64);
        }
      } catch (ex) {}
      return;
    }

    if (isCmd && e.key === "z" && !e.shiftKey) {
      e.preventDefault();
      e.stopPropagation();
      var undoBtn = document.querySelector(".FIE_topbar-undo-button");
      if (undoBtn && !undoBtn.disabled) undoBtn.click();
      return;
    }

    if (isCmd && ((e.key === "z" && e.shiftKey) || e.key === "y")) {
      e.preventDefault();
      e.stopPropagation();
      var redoBtn = document.querySelector(".FIE_topbar-redo-button");
      if (redoBtn && !redoBtn.disabled) redoBtn.click();
      return;
    }

    if (isCmd && (e.key === "a" || e.key === "A")) {
      e.preventDefault();
      return;
    }

    if (e.key === "Delete" || e.key === "Backspace") {
      var tag = e.target.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || e.target.closest("[contenteditable]")) return;
      e.preventDefault();
      e.stopPropagation();
      var delBtn = document.querySelector(".FIE_annotation-remove-button");
      if (delBtn && !delBtn.disabled) delBtn.click();
      return;
    }
  }, true);  // capture phase

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
