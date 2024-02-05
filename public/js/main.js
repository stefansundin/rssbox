let localStorageUsable = false;
try {
  if ('localStorage' in window && localStorage) {
    localStorageUsable = true;
  }
} catch {}

function sign(n) {
  if (n < 0) {
    return "-";
  }
  if (n > 0) {
    return "+";
  }
  return "";
}

function fmt_filesize(bytes, digits=1) {
  const units = ["B", "kiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"];
  let i = 0;
  while (bytes > 1024 && i < units.length) {
    bytes = bytes / 1024;
    i++;
  }
  if (i < 2) digits = 0;
  const size = (i > 0) ? bytes.toFixed(digits) : bytes;
  return `${size} ${units[i]}`;
}

function toObject(arr, f=decodeURIComponent) {
  const obj = {};
  arr.forEach(function(e) {
    obj[e[0]] = f(e[1]);
  });
  return obj;
}

function basename(url) {
  url = url.substr(0, url.indexOf("?")) || url;
  url = url.substr(0, url.indexOf("#")) || url;
  return url.substr(url.lastIndexOf("/")+1);
}

$(document).ready(async function() {
  {
    const links = document.querySelectorAll(".expander");
    for (let i=0; i < links.length; i++) {
      const a = links[i];
      a.style.display = "inline-block";
      a.addEventListener("click", function() {
        const id = this.getAttribute("expand");
        document.getElementById(id).style.display = "block";
        this.style.display = "none";
      });
      const id = a.getAttribute("expand");
      document.getElementById(id).style.display = "none";
    }
  }

  {
    let links = document.querySelectorAll("a[fubar]");
    for (let i=0; i < links.length; i++) {
      const a = links[i];
      if (a.href !== "") {
        continue;
      }
      a.textContent = a.textContent
        .replace(/[A-Z]{2}/, (c) => (c[0] + "@" + c[1]).toLowerCase())
        .replace(/[A-Z]/g, (c) => `.${c.toLowerCase()}`);
      a.href = `mailto:${a.textContent}`;
    }
  }

  {
    const forms = document.querySelectorAll('form[action="https://www.paypal.com/cgi-bin/webscr"]');
    for (let i=0; i < forms.length; i++) {
      const form = forms[i];
      form.addEventListener("submit", function(e) {
        if (parseInt(this.amount.value) < 1) {
          e.preventDefault();
          alert("The minimum donation amount is one dollar. Anything less than one dollar and you're just giving PayPal everything because of their fees.\n\nIf you can't afford one dollar, then please donate to a local charity instead.");
          return false;
        }
      });
    }
  }

  window.dirty = 0;
  $(window).on("beforeunload", function(event) {
    if (window.dirty > 0) {
      event.preventDefault();
      event.returnValue = "There are still files downloading!";
      return event.returnValue;
    }
  });

  $(document).on("show.bs.dropdown", function(e) {
    const form = $(e.target).parents("form");
    const q = form.find("input[name=q]").val();
    form.find("[data-download]").each(function() {
      const btn = $(this);
      const url = `${form.attr("action")}/download?url=${q}`;
      btn.attr("href", url);
    });
    form.find("[data-action]").each(function() {
      const btn = $(this);
      btn.attr("href", `${form.attr("action")}/${btn.attr("data-action")}?url=${q}`);
    });
    form.find("[data-vlc]").each(function() {
      const btn = $(this);
      btn.attr("href", `vlc://${form[0].action}/${btn.attr("data-vlc")}?url=${q}`);
    });
    form.find("[data-irc]").each(function() {
      const btn = $(this);
      const m = /(?:https?:\/\/(?:www\.|clips\.)?twitch\.tv\/)?([^/]+)/.exec(q);
      if (m === null) {
        return;
      }
      const channel = m[1];
      btn.attr("href", `irc://${btn.attr("data-irc")}/${channel}`);
    });
  });

  $("#services form").submit(async function(event) {
    event.preventDefault();

    const form = $(this);
    const action = form.attr("action");
    const qs = form.serialize();
    const submit = form.find('input[type="submit"]');
    const submit_value = submit.attr("value");
    submit.attr("value", "Working...");
    form.find("input").prop("disabled", true);

    const response = await fetch(`${action}?${qs}`, {
      headers: {
        "Accept": "application/json",
      },
    });
    submit.attr("value", submit_value);
    form.find("input").prop("disabled", false);
    if (response.status === 503) {
      // This is usually just HTML garbage when the server request timeout is reached, so print a better error
      alert("Something went wrong. Try again later.");
    }
    else if (!response.ok) {
      alert(await response.text());
      return;
    }

    let url;
    if (response.redirected) {
      url = response.url;
    }
    else {
      const data = await response.json();
      if (data.startsWith("/")) {
        // local feed
        let pathname = window.location.pathname;
        if (pathname.endsWith("/")) {
          pathname = pathname.substring(0, pathname.length-1);
        }
        url = `${window.location.protocol}//${window.location.host}${pathname}${data}`;
        // initiate a request just to get a head start on resolving urls
        fetch(url);
      }
      else {
        // external feed
        url = data;
      }
    }

    const feed_modal = $("#feed-modal");
    const feed_url = $("#feed-url");
    feed_url.val(url).trigger("input");
    feed_modal.modal("show", this);
    feed_url.select();

    return false;
  });

  $("#feed-modal").on("show.bs.modal", function(event) {
    const modal = $(this);
    const form = $(event.relatedTarget);
    const action = form.attr("action");
    const url = $("#feed-url").val();
    console.log(url);
    modal.find("form").hide();
    modal.find(`#${action}-options`).show().attr("action", url).trigger("change");
  });

  $("#copy-button").click(function() {
    const feed_url = $("#feed-url");
    feed_url.select();
    navigator.clipboard.writeText(feed_url.val());
    this.textContent = "Copied";
  });

  $("#feed-url").on("input", function() {
    $("#copy-button").text("Copy");
  });

  $("#feed-modal form").submit(function(event) {
    event.preventDefault();
    return false;
  });

  $("#feed-modal form").change(function() {
    const form = $(this);
    const qs = $.param(form.serializeArray().filter(input => input.value !== ""));
    let url = form.attr("action");
    if (qs !== "") {
      url += `?${qs}`;
    }
    $("#feed-url").val(url).trigger("input").select();
  });

  $("[data-download-filename]").click(async function() {
    const form = $(this).parents("form");
    const q = form.find("input[name=q]").val();
    if (q === "") {
      alert("Please enter a URL.");
      return;
    }

    const response = await fetch(`${form.attr("action")}/download?url=${q}`, {
      headers: {
        "Accept": "application/json",
      },
    });
    if (!response.ok) {
      alert(await response.text());
      return;
    }
    let data = await response.json();
    if (!Array.isArray(data)) {
      data = [data];
    }

    data.forEach(async (file, i) => {
      if (file.live) {
        $(`<div><p><tt>ffmpeg -i "${file.url}" "${file.filename}"</tt></p></div>`).insertAfter(form);
        return;
      }

      // this is a big hack for cross-origin <a download="filename">
      window.dirty++;
      const controller = new AbortController();
      const progress = document.createElement("progress");
      progress.title = file.filename;
      $(progress).click(function() {
        if (confirm(`Abort download of "${file.filename}"?`)) {
          controller.abort();
          window.dirty--;
          $(this).off("click");
        }
      });
      $(progress).insertAfter(form);

      const response = await fetch(file.url, {
        signal: controller.signal,
      });
      if (!response.ok) {
        alert(await response.text());
        return;
      }
      progress.max = parseInt(response.headers.get("Content-Length"), 10);

      const reader = response.body.getReader();
      const parts = [];
      while (true) {
        const {value, done} = await reader.read();
        console.log(i, value?.length, done);
        if (done) {
          break;
        }
        parts.push(value);
        progress.value += value.length;
        progress.title = `${fmt_filesize(progress.value)} / ${fmt_filesize(progress.max)} (${(progress.value/progress.max*100).toFixed(1)}%) of ${file.filename}`;
      }

      const blob = new Blob(parts);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.style.display = "none";
      a.href = url;
      a.download = file.filename;
      document.body.appendChild(a);
      a.click();
      setTimeout(() => {
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
        window.dirty--;
      }, 100);
    });
  });

  const tz_offset = -new Date().getTimezoneOffset();
  if (tz_offset !== 0) {
    $("#youtube_q").after($('<input type="hidden" name="tz">').val(`${sign(tz_offset)}${Math.abs(tz_offset/60).toString().padStart(2,'0')}:${Math.abs(tz_offset%60).toString().padStart(2,'0')}`));
  }

  const params = toObject(window.location.search.substring(1).split("&").map((arg) => arg.split("=")));
  if (params.q) {
    $('input[type="search"]').val(params.q);
  }
  const url = params.download || params.go;
  if (url) {
    const m = /([a-z0-9]+)\.[^./]+\//.exec(url);
    if (m) {
      const input = $(`#${m[1]}_q`);
      if (input[0]) {
        input[0].scrollIntoView({ block: "center" });
        input.val(url);
        const form = input.parents("form");
        if (params.download) {
          form.find("[data-download-filename]").click();
        }
        else {
          form.submit();
        }
      }
      else if (params.go) {
        const response = await fetch(`go?q=${encodeURIComponent(params.go)}`, {
          headers: {
            "Accept": "application/json",
          },
        });
        if (!response.ok) {
          alert(await response.text());
          return;
        }
        const url = await response.json();
        const feed_modal = $("#feed-modal");
        const feed_url = $("#feed-url");
        feed_url.val(url);
        feed_modal.modal("show");
        feed_url.select();
      }
    }
  }

  // Only show dark mode switch if JavaScript is enabled
  $(".js-show").removeClass("d-none");
});


// Dark mode

document.addEventListener("DOMContentLoaded", () => {
  const checkbox = document.getElementById("dark-mode");
  const label = checkbox.parentElement.querySelector('label[for="dark-mode"]');
  for (const el of [checkbox, label]) {
    el.addEventListener("click", (e) => {
      if (e.isTrusted && localStorageUsable) {
        // user initiated
        if (e.shiftKey) {
          localStorage.removeItem("theme");
          checkbox.checked = window.matchMedia("(prefers-color-scheme: dark)").matches;
          checkbox.indeterminate = true;
        }
        else {
          localStorage.setItem("theme", (checkbox.checked ? "dark" : "light"));
        }
      }

      const theme = (checkbox.checked ? 'dark' : 'light');
      document.documentElement.setAttribute('data-bs-theme', theme);
    });
  }

  // Pass theme=dark in the query string to default to dark mode
  let theme = window.location.search.substring(1).split('&').find(v => v.startsWith('theme='))?.split('=')?.[1]
  if (localStorageUsable) {
    // localStorage has preference over query parameter
    const localTheme = localStorage.getItem("theme");
    if (localTheme) {
      theme = localTheme;
    }
  }
  if (theme === "dark" || (theme === undefined && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
    checkbox.click();
  }
  checkbox.indeterminate = (theme === undefined);
});

window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
  const checkbox = document.getElementById("dark-mode");
  if (checkbox.indeterminate && checkbox.checked !== e.matches) {
    checkbox.click();
    checkbox.indeterminate = true;
  }
});
