let localStorageUsable = false;
try {
  if ('localStorage' in window && localStorage) {
    localStorageUsable = true;
  }
} catch {}

function sign(n) {
  if (n < 0) {
    return '-';
  } else if (n > 0) {
    return '+';
  }
  return '';
}

function formatFilesize(bytes, digits=1) {
  const units = ['B', 'kiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'];
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
  for (const [name, value] of arr) {
    obj[name] = f(value);
  }
  return obj;
}

function basename(url) {
  url = url.substring(0, url.indexOf('?')) || url;
  url = url.substring(0, url.indexOf('#')) || url;
  return url.substring(url.lastIndexOf('/')+1);
}

// fly sometimes return "502 Bad Gateway" errors and it works on the second try, so retry at most once
async function fetchWithRetry(resource, options) {
  let response = await fetch(resource, options);
  if (response.status === 502) {
    response = await fetch(resource, options);
  }
  return response;
}

document.addEventListener('DOMContentLoaded', async function() {
  {
    const links = document.querySelectorAll('.expander');
    for (const a of links) {
      a.style.display = 'inline-block';
      a.addEventListener('click', function() {
        const id = this.getAttribute('expand');
        document.getElementById(id).style.display = 'block';
        this.style.display = 'none';
      });
      const id = a.getAttribute('expand');
      document.getElementById(id).style.display = 'none';
    }
  }

  {
    let links = document.querySelectorAll('a[fubar]');
    for (const a of links) {
      if (a.href !== '') {
        continue;
      }
      a.textContent = a.textContent
        .replace(/[A-Z]{2}/, (c) => (`${c[0]}@${c[1]}`).toLowerCase())
        .replace(/[A-Z]/g, (c) => `.${c.toLowerCase()}`);
      a.href = `mailto:${a.textContent}`;
    }
  }

  {
    const forms = document.querySelectorAll('form[action="https://www.paypal.com/cgi-bin/webscr"]');
    for (const form of forms) {
      form.addEventListener('submit', function(e) {
        if (parseInt(this.amount.value) < 1) {
          e.preventDefault();
          alert("The minimum donation amount is one dollar. Anything less than one dollar and you're just giving PayPal everything because of their fees.");
          return false;
        }
      });
    }
  }

  const feedModal = new bootstrap.Modal('#feed-modal');
  const feedUrlInput = document.querySelector('#feed-url');

  let dirty = 0;
  window.addEventListener('beforeunload', function(event) {
    if (dirty > 0) {
      event.preventDefault();
      event.returnValue = 'There are still files downloading!';
      return event.returnValue;
    }
  });

  document.addEventListener('show.bs.dropdown', function(event) {
    const form = event.target.parentElement;
    const q = form.elements.namedItem('q').value;
    for (const button of form.querySelectorAll('[data-download]')) {
      button.href = `${form.getAttribute('action')}/download?url=${q}`;
    }
    for (const button of form.querySelectorAll('[data-action]')) {
      button.href = `${form.getAttribute('action')}/${button.dataset.action}?url=${q}`;
    }
    for (const button of form.querySelectorAll('[data-vlc]')) {
      button.href = `vlc://${form.action}/${button.dataset.vlc}?url=${q}`;
    }
    for (const button of form.querySelectorAll('[data-irc]')) {
      const m = /(?:https?:\/\/(?:www\.|clips\.)?twitch\.tv\/)?([^/]+)/.exec(q);
      if (m === null) {
        return;
      }
      const channel = m[1];
      button.href = `irc://${button.dataset.irc}/${channel}`;
    }
  });

  let shiftKey = false;
  document.addEventListener('keydown', function (e) {
    shiftKey = e.shiftKey;
  });
  document.addEventListener('keyup', function (e) {
    shiftKey = e.shiftKey;
  });

  async function submitForm(event) {
    event.preventDefault();

    const action = this.getAttribute('action');
    const data = new FormData(this);
    let qs = new URLSearchParams(data).toString();
    if (shiftKey) {
      qs += '&shift';
    }
    const oldButtonValue = event.submitter.value;
    event.submitter.value = 'Working...';
    for (const input of this.elements) {
      input.disabled = true;
    }

    const response = await fetchWithRetry(`${action}?${qs}`, {
      headers: {
        'Accept': 'application/json',
      },
    });
    event.submitter.value = oldButtonValue;
    for (const input of this.elements) {
      input.disabled = false;
    }
    if (response.status === 503) {
      // This is usually just HTML garbage when the server request timeout is reached, so print a better error
      alert('Something went wrong. Try again later.');
    } else if (!response.ok) {
      const body = await response.text();
      let error = `Received an error response. HTTP code: ${response.status}`;
      if (body) {
        error += `\n${body}`;
      }
      alert(error);
      return;
    }

    let url;
    if (response.redirected) {
      url = response.url;
    } else {
      const data = await response.json();
      if (data.startsWith('/')) {
        // local feed
        let pathname = window.location.pathname;
        if (pathname.endsWith('/')) {
          pathname = pathname.substring(0, pathname.length-1);
        }
        url = `${window.location.origin}${pathname}${data}`;
        // initiate a request just to get a head start on resolving urls
        fetch(url);
      } else {
        // external feed
        url = data;
      }
    }

    // Normalize URL
    const uri = new URL(url);
    uri.search = uri.searchParams.toString();
    url = uri.toString();

    feedUrlInput.value = url;
    feedUrlInput.dispatchEvent(new InputEvent('input'));
    feedModal.show(this);
    feedUrlInput.select();

    return false;
  }

  for (const form of document.querySelectorAll('#services form')) {
    form.addEventListener('submit', submitForm);
  }

  document.addEventListener('shown.bs.modal', function (event) {
    const form = event.relatedTarget;
    const action = form.getAttribute('action');
    const url = feedUrlInput.value;
    console.log(url);
    for (const form of event.target.querySelectorAll('form')) {
      form.reset();
      form.classList.add('d-none');
    }
    if (url.startsWith(window.location.origin)) {
      if (action === 'youtube') {
        const uri = new URL(url);
        const q = uri.searchParams.get('q');
        if (q) {
          document.querySelector('#youtube_title_filter').value = q;
        }
      }
      const formOptions = event.target.querySelector(`#${action}-options`);
      formOptions.classList.remove('d-none');
      formOptions.action = url;
    }
  });

  const copyButton = document.querySelector('#copy-button');
  copyButton.addEventListener('click', function() {
    feedUrlInput.select();
    navigator.clipboard.writeText(feedUrlInput.value);
    this.textContent = 'Copied';
  });
  feedUrlInput.addEventListener('input', function() {
    copyButton.textContent = 'Copy';
  });

  for (const form of document.querySelectorAll('#feed-modal form')) {
    form.addEventListener('submit', function(event) {
      event.preventDefault();
      return false;
    });

    form.addEventListener('input', function(event) {
      const uri = new URL(this.action);
      const data = new FormData(this);
      for (const [name, value] of data.entries()) {
        if (value === '') {
          if (uri.searchParams.has(name)) {
            uri.searchParams.delete(name);
          }
          continue;
        }
        uri.searchParams.set(name, value);
      }
      const url = uri.toString();
      feedUrlInput.value = url;
      feedUrlInput.dispatchEvent(new InputEvent('input'));
      if (event.target.tagName !== "INPUT" || event.target.type !== "text") {
        feedUrlInput.select();
      }
    });
  }

  const tzOffset = -new Date().getTimezoneOffset();
  if (tzOffset !== 0) {
    const tzInput = document.createElement('input');
    tzInput.name = 'tz';
    tzInput.type = 'hidden';
    tzInput.value = `${sign(tzOffset)}${Math.abs(tzOffset/60).toString().padStart(2,'0')}:${Math.abs(tzOffset%60).toString().padStart(2,'0')}`;
    document.querySelector('form[action="youtube"]').appendChild(tzInput);
  }

  const params = toObject(window.location.search.substring(1).split('&').map((arg) => arg.split('=')));
  if (params.q) {
    for (const input of document.querySelectorAll('input[type="search"]')) {
      input.value = params.q;
    }
  }
  const url = params.download || params.go;
  if (url) {
    const m = /([a-z0-9]+)\.[^./]+\//.exec(url);
    if (m) {
      const input = document.querySelector(`#${m[1]}_q`);
      if (input) {
        input.scrollIntoView({ block: 'center' });
        input.value = url;
        const form = input.parentElement;
        form.requestSubmit(form.querySelector('input[type="submit"]'));
      } else if (params.go) {
        const response = await fetchWithRetry(`go?q=${encodeURIComponent(params.go)}`, {
          headers: {
            'Accept': 'application/json',
          },
        });
        if (!response.ok) {
          alert(await response.text());
          return;
        }
        const url = await response.json();
        feedUrlInput.value = url;
        feedModal.show();
        feedUrlInput.select();
      }
    }
  }

  // Only show dark mode switch if JavaScript is enabled
  for (const el of document.querySelectorAll('.js-show')) {
    el.classList.remove('d-none');
  }

  // Dark mode
  const checkbox = document.getElementById('dark-mode');
  const label = checkbox.parentElement.querySelector('label[for="dark-mode"]');
  for (const el of [checkbox, label]) {
    el.addEventListener('click', (e) => {
      if (e.isTrusted && localStorageUsable) {
        // user initiated
        if (e.shiftKey) {
          localStorage.removeItem("theme");
          checkbox.checked = window.matchMedia('(prefers-color-scheme: dark)').matches;
          checkbox.indeterminate = true;
        } else {
          localStorage.setItem('theme', checkbox.checked ? 'dark' : 'light');
        }
      }

      const theme = checkbox.checked ? 'dark' : 'light';
      document.documentElement.setAttribute('data-bs-theme', theme);
    });
  }

  // Pass theme=dark in the query string to default to dark mode
  let theme = window.location.search.substring(1).split('&').find(v => v.startsWith('theme='))?.split('=')?.[1]
  if (localStorageUsable) {
    // localStorage has preference over query parameter
    const localTheme = localStorage.getItem('theme');
    if (localTheme) {
      theme = localTheme;
    }
  }
  if (theme === 'dark' || (theme === undefined && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    checkbox.click();
  }
  checkbox.indeterminate = (theme === undefined);
});

window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
  const checkbox = document.getElementById('dark-mode');
  if (checkbox.indeterminate && checkbox.checked !== e.matches) {
    checkbox.click();
    checkbox.indeterminate = true;
  }
});
