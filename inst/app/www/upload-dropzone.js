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
    var dragDepth = 0;

    function syncHasFileState() {
      var hasFile = fileInput.files && fileInput.files.length > 0;
      dropzone.classList.toggle("has-file", !!hasFile);
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
  }

  function bindAllDropzones() {
    var dropzones = document.querySelectorAll(".upload-dropzone");
    Array.prototype.forEach.call(dropzones, bindDropzone);
  }

  function init() {
    bindAllDropzones();

    if (!window.__finchUploadDropzoneObserver && document.body) {
      window.__finchUploadDropzoneObserver = new MutationObserver(function () {
        bindAllDropzones();
      });

      window.__finchUploadDropzoneObserver.observe(document.body, {
        childList: true,
        subtree: true
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
