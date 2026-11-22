// Page behaviour for the inventory app. Plain browser JavaScript, no build step.
// Third-party controls (Bootstrap, SortableJS, Tom Select, EasyMDE) are loaded from a CDN in the layout.
(() => {
  "use strict";

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const i18n = JSON.parse(document.body.dataset.i18n || "{}");

  function request(url, { method = "GET", body, keepalive = false } = {}) {
    const headers = { "X-Requested-With": "XMLHttpRequest", Accept: "application/json, text/html" };
    const token = $('meta[name="csrf-token"]');
    if (token) headers["X-CSRF-Token"] = token.content;
    if (body !== undefined) headers["Content-Type"] = "application/json";

    return fetch(url, {
      method, headers, keepalive, credentials: "same-origin",
      body: body === undefined ? undefined : JSON.stringify(body)
    });
  }

  // ---------------------------------------------------------------------
  // Tables with a toolbar: rows are selected with checkboxes, the actions
  // live in one toolbar above the table instead of buttons in every row.
  // ---------------------------------------------------------------------
  function initBulkTables() {
    $$("[data-bulk-toolbar]").forEach((toolbar) => {
      const form = document.getElementById(toolbar.dataset.bulkToolbar);
      if (!form) return;

      const boxes = () => $$("[data-bulk-item]", form);
      const all = $("[data-bulk-all]", form);

      const refresh = () => {
        const checked = boxes().filter((box) => box.checked).length;
        $$("[data-bulk-min]", toolbar).forEach((button) => { button.disabled = checked < Number(button.dataset.bulkMin); });
        $$("[data-bulk-edit]", toolbar).forEach((button) => { button.disabled = checked !== 1; });
        if (all) {
          all.checked = checked > 0 && checked === boxes().length;
          all.indeterminate = checked > 0 && !all.checked;
        }
      };

      form.addEventListener("change", (event) => {
        if (event.target === all) boxes().forEach((box) => { box.checked = all.checked; });
        refresh();
      });

      // A click on the row itself (not on a link or a control) toggles its checkbox.
      form.addEventListener("click", (event) => {
        if (event.target.closest("a, input, button, label")) return;
        const box = event.target.closest("tr") && $("[data-bulk-item]", event.target.closest("tr"));
        if (box) { box.checked = !box.checked; refresh(); }
      });

      toolbar.addEventListener("click", (event) => {
        if (event.target.closest("[data-bulk-edit]")) {
          const box = boxes().find((item) => item.checked);
          if (box) window.location.href = box.dataset.href;
          return;
        }
        const button = event.target.closest("[data-confirm]");
        if (button && !window.confirm(button.dataset.confirm)) event.preventDefault();
      });

      refresh();
    });
  }

  // ---------------------------------------------------------------------
  // Auto-save of the inventory page with optimistic locking.
  // Changes are only tracked; every 8 seconds the pending ones are sent
  // together with the version the page has. The server answers with the
  // next version, or with 409 when somebody else saved in the meantime.
  // ---------------------------------------------------------------------
  const AUTOSAVE_INTERVAL = 8000;

  function initAutosave() {
    const root = $("[data-autosave]");
    const state = { collectors: [], markDirty() {}, save: async () => {} };
    if (!root) return state;

    const badge = $("[data-autosave-status]");
    const alertBox = $("[data-autosave-conflict]", root);
    let version = Number(root.dataset.version);
    let dirty = false;
    let saving = false;
    let stopped = false;

    const status = (key, style) => {
      if (!badge) return;
      badge.textContent = i18n[key] || key;
      badge.className = `badge rounded-pill text-bg-${style}`;
    };
    const showMessage = (text) => {
      if (!alertBox) return;
      $("[data-autosave-message]", alertBox).textContent = text || "";
      alertBox.classList.toggle("d-none", !text);
    };

    state.markDirty = () => {
      if (stopped) return;
      dirty = true;
      status("unsaved", "warning");
    };

    state.save = async (keepalive = false) => {
      if (!dirty || saving || stopped) return;
      saving = true;
      dirty = false;
      status("saving", "secondary");

      const payload = { lock_version: version };
      state.collectors.forEach((collect) => Object.assign(payload, collect()));

      try {
        const response = await request(root.dataset.url, { method: "PATCH", body: payload, keepalive });
        const data = await response.json().catch(() => ({}));

        if (response.ok) {
          version = data.lock_version;
          showMessage("");
          status(dirty ? "unsaved" : "saved", dirty ? "warning" : "success");
          document.dispatchEvent(new CustomEvent("inventory:saved", { detail: data }));
        } else if (response.status === 409) {
          // Our copy is outdated. Stop saving so nothing gets overwritten; the user reloads.
          stopped = true;
          status("conflict", "danger");
          showMessage(data.error || i18n.conflict);
        } else {
          status("error", "danger");
          showMessage(data.error || i18n.error);
        }
      } catch (error) {
        dirty = true; // network problem: try again on the next tick
        status("offline", "danger");
      } finally {
        saving = false;
      }
    };

    const tracked = "[data-autosave-form], [data-fields-editor], [data-id-editor]";
    const onEdit = (event) => { if (event.target.closest(tracked)) state.markDirty(); };
    root.addEventListener("input", onEdit);
    root.addEventListener("change", onEdit);

    window.setInterval(() => state.save(), AUTOSAVE_INTERVAL);

    // Do not lose pending changes when the user moves to another tab or page.
    document.addEventListener("click", async (event) => {
      const link = event.target.closest("a[href]");
      if (!link || !dirty || stopped || link.target === "_blank" || link.getAttribute("href").startsWith("#")) return;
      event.preventDefault();
      await state.save();
      window.location.href = link.href;
    });
    document.addEventListener("submit", async (event) => {
      if (!dirty || stopped || event.defaultPrevented) return;
      const form = event.target;
      event.preventDefault();
      await state.save();
      form.submit();
    });
    window.addEventListener("pagehide", () => state.save(true));

    document.addEventListener("inventory:saved", (event) => {
      const title = $("[data-inventory-title]");
      if (title && event.detail.title) title.textContent = event.detail.title;
    });

    // Plain inputs of the settings and access tabs: <input data-field="title"> etc.
    state.collectors.push(() => {
      const inventory = {};
      $$("[data-autosave-form] [data-field]", root).forEach((input) => {
        if (input.type === "checkbox") inventory[input.dataset.field] = input.checked;
        else if (input.multiple) inventory[input.dataset.field] = Array.from(input.selectedOptions).map((option) => option.value);
        else inventory[input.dataset.field] = input.value;
      });
      return Object.keys(inventory).length ? { inventory } : {};
    });

    return state;
  }

  // ---------------------------------------------------------------------
  // Settings tab: Markdown editor, tags, image upload.
  // ---------------------------------------------------------------------
  function initSettings(autosave) {
    $$("textarea[data-markdown]").forEach((textarea) => {
      if (!window.EasyMDE) return;
      const editor = new window.EasyMDE({
        element: textarea, forceSync: true, spellChecker: false, status: false, minHeight: "160px",
        toolbar: ["bold", "italic", "heading", "|", "unordered-list", "ordered-list", "link", "code", "|", "preview", "guide"]
      });
      editor.codemirror.on("change", () => autosave.markDirty());
    });

    $$("select[data-tags]").forEach((select) => {
      if (!window.TomSelect) return;
      new window.TomSelect(select, {
        plugins: ["remove_button"], create: true, persist: false, maxItems: 20, loadThrottle: 200,
        valueField: "value", labelField: "text", searchField: ["text"],
        // The server returns existing tags that start with the typed text.
        load(query, callback) {
          fetch(`${select.dataset.url}?q=${encodeURIComponent(query)}`, { credentials: "same-origin" })
            .then((response) => response.json())
            .then((names) => callback(names.map((name) => ({ value: name, text: name }))))
            .catch(() => callback());
        },
        onChange: () => autosave.markDirty()
      });
    });

    const input = $('[data-field="image_url"]');
    const preview = $("[data-image-preview]");
    const setImage = (url) => {
      input.value = url;
      if (url) preview.src = url; else preview.removeAttribute("src");
      preview.classList.toggle("d-none", !url);
      autosave.markDirty();
    };

    // The file goes from the browser straight to Cloudinary; only the URL is saved.
    let widget;
    const upload = $("[data-cloudinary]");
    if (upload) {
      upload.addEventListener("click", () => {
        if (!window.cloudinary) return;
        widget = widget || window.cloudinary.createUploadWidget(
          { cloudName: upload.dataset.cloud, uploadPreset: upload.dataset.preset, multiple: false, maxFiles: 1,
            resourceType: "image", sources: ["local", "url", "camera"] },
          (error, result) => { if (!error && result && result.event === "success") setImage(result.info.secure_url); }
        );
        widget.open();
      });
    }
    const remove = $("[data-image-remove]");
    if (remove) remove.addEventListener("click", () => setImage(""));
  }

  // ---------------------------------------------------------------------
  // Custom ID tab: ordered list of elements with a live example.
  // ---------------------------------------------------------------------
  function initIdEditor(autosave) {
    const editor = $("[data-id-editor]");
    if (!editor) return;

    const list = $("[data-id-list]", editor);
    const addButton = $("[data-id-add]", editor);
    const example = $("[data-id-example]");
    const max = Number(editor.dataset.max);
    const hints = JSON.parse(editor.dataset.hints);
    const help = JSON.parse(editor.dataset.help);
    const defaults = JSON.parse(editor.dataset.defaults);

    const rows = () => $$("[data-id-element]", list);
    const elements = () => rows().map((row) => ({
      kind: $('[data-prop="kind"]', row).value,
      format: $('[data-prop="format"]', row).value
    }));

    const setupRow = (row) => {
      const kind = $('[data-prop="kind"]', row).value;
      $("[data-id-hint]", row).textContent = hints[kind];
      $('[data-prop="format"]', row).placeholder = defaults[kind] || "";

      const button = $("[data-id-help]", row);
      if (window.bootstrap) {
        const old = window.bootstrap.Popover.getInstance(button);
        if (old) old.dispose();
        new window.bootstrap.Popover(button, { content: help[kind], trigger: "focus", placement: "auto", customClass: "id-help-popover" });
      }
    };

    let timer;
    const preview = () => {
      window.clearTimeout(timer);
      timer = window.setTimeout(async () => {
        try {
          const response = await request(editor.dataset.previewUrl, { method: "POST", body: { id_elements: elements() } });
          if (response.ok) example.textContent = (await response.json()).example;
        } catch (error) { /* the example is refreshed on the next change */ }
      }, 250);
    };

    const changed = () => {
      addButton.disabled = rows().length >= max;
      autosave.markDirty();
      preview();
    };

    list.addEventListener("input", changed);
    list.addEventListener("change", (event) => {
      if (event.target.matches('[data-prop="kind"]')) {
        const row = event.target.closest("[data-id-element]");
        $('[data-prop="format"]', row).value = defaults[event.target.value] || "";
        setupRow(row);
      }
      changed();
    });

    addButton.addEventListener("click", () => {
      if (rows().length >= max) return;
      const row = $("[data-id-template]", editor).content.firstElementChild.cloneNode(true);
      list.appendChild(row);
      setupRow(row);
      $('[data-prop="format"]', row).focus();
      changed();
    });

    if (window.Sortable) {
      // Drag to reorder; drop an element outside the list to delete it.
      window.Sortable.create(list, {
        handle: ".drag-handle", animation: 150, removeOnSpill: true,
        onEnd: () => window.setTimeout(changed, 0)
      });
    }

    rows().forEach(setupRow);
    addButton.disabled = rows().length >= max;
    autosave.collectors.push(() => ({ id_elements: elements() }));
  }

  // ---------------------------------------------------------------------
  // Fields tab. Every field type has a fixed number of slots; a new field
  // takes the first free slot of its type.
  // ---------------------------------------------------------------------
  function initFieldsEditor(autosave) {
    const editor = $("[data-fields-editor]");
    if (!editor) return;

    const list = $("[data-fields-list]", editor);
    const deleteButton = $("[data-fields-delete]", editor);
    const max = Number(editor.dataset.max);
    const rows = () => $$("[data-field-row]", list);
    const selected = () => rows().filter((row) => $("[data-field-select]", row).checked);

    const refresh = () => {
      $$("[data-field-add]", editor).forEach((button) => {
        button.disabled = rows().filter((row) => row.dataset.kind === button.dataset.fieldAdd).length >= max;
      });
      deleteButton.disabled = selected().length === 0;
      $("[data-fields-empty]", editor).classList.toggle("d-none", rows().length > 0);
    };

    editor.addEventListener("click", (event) => {
      const add = event.target.closest("[data-field-add]");
      if (add) {
        const kind = add.dataset.fieldAdd;
        const used = rows().filter((row) => row.dataset.kind === kind).map((row) => Number(row.dataset.slot));
        const slot = Array.from({ length: max }, (_, index) => index + 1).find((number) => !used.includes(number));
        if (!slot) return;

        const row = $(`[data-field-template="${kind}"]`, editor).content.firstElementChild.cloneNode(true);
        row.dataset.slot = slot;
        list.appendChild(row);
        $('[data-prop="name"]', row).focus();
        autosave.markDirty();
        refresh();
      } else if (event.target.closest("[data-fields-delete]")) {
        selected().forEach((row) => row.remove());
        autosave.markDirty();
        refresh();
      }
    });
    editor.addEventListener("change", refresh);

    if (window.Sortable) {
      window.Sortable.create(list, { handle: ".drag-handle", animation: 150, onEnd: () => autosave.markDirty() });
    }

    refresh();
    autosave.collectors.push(() => ({
      fields: rows().map((row) => {
        const field = { kind: row.dataset.kind, slot: Number(row.dataset.slot) };
        $$("[data-prop]", row).forEach((input) => {
          field[input.dataset.prop] = input.type === "checkbox" ? input.checked : input.value;
        });
        return field;
      })
    }));
  }

  // ---------------------------------------------------------------------
  // Access tab: find a user by name or e-mail and add them right away.
  // ---------------------------------------------------------------------
  function initUserSearch() {
    $$("select[data-user-search]").forEach((select) => {
      if (!window.TomSelect) return;
      new window.TomSelect(select, {
        valueField: "id", labelField: "name", searchField: ["name", "email"], maxItems: 1, loadThrottle: 200,
        load(query, callback) {
          fetch(`${select.dataset.url}?q=${encodeURIComponent(query)}`, { credentials: "same-origin", headers: { Accept: "application/json" } })
            .then((response) => response.json()).then(callback).catch(() => callback());
        },
        render: {
          option: (user, escape) => `<div><span class="fw-medium">${escape(user.name)}</span> <span class="text-body-secondary small">${escape(user.email)}</span></div>`,
          item: (user, escape) => `<div>${escape(user.name)} &lt;${escape(user.email)}&gt;</div>`
        },
        onChange: (value) => { if (value) select.form.requestSubmit(); }
      });
    });
  }

  // ---------------------------------------------------------------------
  // Discussion tab: new posts are appended at the end and picked up from
  // the server every 3 seconds, so everybody sees them almost at once.
  // ---------------------------------------------------------------------
  const CHAT_INTERVAL = 3000;

  function initChat() {
    const chat = $("[data-chat]");
    if (!chat) return;

    const list = $("[data-chat-list]", chat);
    const empty = $("[data-chat-empty]", chat);
    const form = $("[data-chat-form]", chat);
    let busy = false;

    const lastId = () => {
      const posts = $$("[data-post-id]", list);
      return posts.length ? posts[posts.length - 1].dataset.postId : 0;
    };

    const poll = async () => {
      if (busy) return;
      busy = true;
      try {
        const response = await fetch(`${chat.dataset.url}?after=${lastId()}`, { credentials: "same-origin", headers: { Accept: "text/html" } });
        const html = response.ok ? (await response.text()).trim() : "";
        if (html) {
          list.insertAdjacentHTML("beforeend", html);
          empty.classList.add("d-none");
        }
      } catch (error) { /* try again on the next tick */ } finally {
        busy = false;
      }
    };

    window.setInterval(() => { if (!document.hidden) poll(); }, CHAT_INTERVAL);

    if (!form) return;
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const textarea = form.elements.body;
      const errorBox = $("[data-chat-error]", form);
      const button = $('button[type="submit"]', form);
      if (!textarea.value.trim()) return;

      button.disabled = true;
      errorBox.textContent = "";
      try {
        const response = await request(chat.dataset.url, { method: "POST", body: { body: textarea.value } });
        if (response.ok) {
          textarea.value = "";
          await poll();
        } else {
          const data = await response.json().catch(() => ({}));
          errorBox.textContent = data.error || i18n.error;
        }
      } catch (error) {
        errorBox.textContent = i18n.offline;
      } finally {
        button.disabled = false;
      }
    });
  }

  // Lets the server render dates in the visitor's time zone.
  function rememberTimeZone() {
    try {
      const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      if (zone) document.cookie = `tz=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`;
    } catch (error) { /* dates stay in UTC */ }
  }

  document.addEventListener("DOMContentLoaded", () => {
    rememberTimeZone();
    initBulkTables();
    const autosave = initAutosave();
    initSettings(autosave);
    initIdEditor(autosave);
    initFieldsEditor(autosave);
    initUserSearch();
    initChat();
  });
})();
