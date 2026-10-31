(function () {
  "use strict";

  function hasFiles(event) {
    if (!event || !event.dataTransfer || !event.dataTransfer.types) return false;

    var types = event.dataTransfer.types;

    if (typeof types.contains === "function") {
      return types.contains("Files");
    }

    if (typeof types.indexOf === "function") {
      return types.indexOf("Files") !== -1;
    }

    for (var i = 0; i < types.length; i += 1) {
      if (types[i] === "Files") return true;
      if (typeof types.item === "function" && types.item(i) === "Files") return true;
    }

    return false;
  }

  function setFilesOnInput(input, files) {
    if (!input || !files || !files.length) return;

    try {
      var dataTransfer = new DataTransfer();
      Array.prototype.forEach.call(files, function (file) {
        dataTransfer.items.add(file);
      });
      input.files = dataTransfer.files;
    } catch (error) {
      try {
        input.files = files;
      } catch (assignError) {
        return;
      }
    }

    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  function bindDropzone(dropzone) {
    if (!dropzone || dropzone.dataset.dropzoneBound === "true") return;

    var section = dropzone.closest(".upload-section");
    var fileInput = dropzone.querySelector("input.shiny-input-file[type='file'], input[type='file']");
    if (!fileInput && section) {
      fileInput = section.querySelector(".upload-native-input input.shiny-input-file[type='file'], .upload-native-input input[type='file']");
    }
    if (!fileInput && section) {
      fileInput = section.querySelector("input.shiny-input-file[type='file'], input[type='file']");
    }
    if (!fileInput) return;

    var inputGroup = dropzone.querySelector(".input-group");
    if (!inputGroup && section) {
      inputGroup = section.querySelector(".upload-native-input .input-group");
    }
    if (inputGroup && !dropzone.dataset.dropzoneInputDetached) {
      try {
        // Detach the native file input from Shiny's visual shell so we can
        // hide the shell while keeping the file picker callable via JS click.
        dropzone.appendChild(fileInput);
        inputGroup.remove();
        dropzone.dataset.dropzoneInputDetached = "true";
      } catch (error) {
        // Non-fatal: keep default structure if detach fails.
      }
    }

    dropzone.dataset.dropzoneBound = "true";
    observeProgress(section);
    var dragDepth = 0;

    var fileNameEl = dropzone.querySelector(".upload-dropzone-filename");

    function syncHasFileState() {
      var hasFile = fileInput.files && fileInput.files.length > 0;
      dropzone.classList.toggle("has-file", !!hasFile);
      if (fileNameEl) fileNameEl.textContent = hasFile ? fileInput.files[0].name : "";
    }

    fileInput.addEventListener("change", syncHasFileState);
    syncHasFileState();

    dropzone.addEventListener("dragenter", function (event) {
      event.preventDefault();
      event.stopPropagation();
      if (!hasFiles(event)) return;
      dragDepth += 1;
      dropzone.classList.add("is-dragover");
    });

    dropzone.addEventListener("dragover", function (event) {
      event.preventDefault();
      event.stopPropagation();
      if (!hasFiles(event)) return;
      event.dataTransfer.dropEffect = "copy";
      dropzone.classList.add("is-dragover");
    });

    dropzone.addEventListener("dragleave", function (event) {
      event.preventDefault();
      event.stopPropagation();
      if (dropzone.classList.contains("is-dragover")) {
        dragDepth = Math.max(0, dragDepth - 1);
        if (dragDepth === 0) {
          dropzone.classList.remove("is-dragover");
        }
      }
    });

    dropzone.addEventListener("drop", function (event) {
      event.preventDefault();
      event.stopPropagation();
      dragDepth = 0;
      dropzone.classList.remove("is-dragover");

      if (!event.dataTransfer || !event.dataTransfer.files || !event.dataTransfer.files.length) return;
      setFilesOnInput(fileInput, event.dataTransfer.files);
      syncHasFileState();
    });

    dropzone.addEventListener("click", function (event) {
      if (event.target === fileInput) return;
      fileInput.click();
    });

    // The Home dropzone is a role="button" with no visible picker button, so
    // Enter and Space must open the picker as a click does.
    dropzone.addEventListener("keydown", function (event) {
      if (event.target !== dropzone) return;
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      fileInput.click();
    });
  }

  // Shiny writes "Upload complete" in English into the progress bar, with no
  // option to translate it. The server sends the label in the current
  // language, and each upload's bar swaps the text whenever Shiny writes it.
  var uploadCompleteLabel = null;

  function localizeBar(bar) {
    // In English the label equals Shiny's text: writing it again would fire
    // the bar's MutationObserver, which calls this again, without end.
    if (uploadCompleteLabel && bar.textContent === "Upload complete" &&
        uploadCompleteLabel !== bar.textContent) {
      bar.textContent = uploadCompleteLabel;
    }
  }

  function localizeUploadProgress() {
    var bars = document.querySelectorAll(".shiny-file-input-progress .progress-bar");
    Array.prototype.forEach.call(bars, localizeBar);
  }

  // One observer per upload bar: an observer on the page body ran on each
  // change of every tab, table and modal.
  function observeProgress(section) {
    var bar = section && section.querySelector(".shiny-file-input-progress .progress-bar");
    if (!bar) return;
    new MutationObserver(function () {
      localizeBar(bar);
    }).observe(bar, { childList: true, characterData: true, subtree: true });
  }

  function registerUploadLabelHandler() {
    if (!window.Shiny || window.__sairaUploadLabelHandler) return;
    window.__sairaUploadLabelHandler = true;
    window.Shiny.addCustomMessageHandler("saira-upload-complete-label", function (msg) {
      uploadCompleteLabel = msg && msg.label ? msg.label : null;
      localizeUploadProgress();
    });
  }

  function bindAllDropzones() {
    var dropzones = document.querySelectorAll(".upload-dropzone");
    Array.prototype.forEach.call(dropzones, bindDropzone);
  }

  function init() {
    bindAllDropzones();
    registerUploadLabelHandler();

    // A modal (the mapping guide import) brings its own dropzone. Shiny binds
    // its file input, then the dropzone around it gets bound. jQuery, not
    // addEventListener: Shiny triggers shiny:bound as a jQuery event.
    if (window.jQuery && !window.__sairaUploadBoundHandler) {
      window.__sairaUploadBoundHandler = true;
      window.jQuery(document).on("shiny:bound", function (event) {
        var target = event.target;
        if (event.bindingType !== "input" || !target || target.type !== "file") return;
        var section = target.closest(".upload-section");
        if (!section) return;
        // After Shiny binds the rest of the content: the bind moves this input.
        setTimeout(function () {
          Array.prototype.forEach.call(section.querySelectorAll(".upload-dropzone"), bindDropzone);
        }, 0);
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  document.addEventListener("shiny:connected", bindAllDropzones);
})();
