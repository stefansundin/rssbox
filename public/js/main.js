function fmt_filesize(bytes, digits=1) {
  var units = ['B', 'kiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'];
  var i = 0;
  while (bytes > 1024 && i < units.length) {
    bytes = bytes / 1024;
    i++;
  }
  if (i < 2) digits = 0;
  var size = (i > 0) ? bytes.toFixed(digits) : bytes;
  return `${size} ${units[i]}`;
}

function toObject(arr) {
  var obj = {};
  arr.forEach(function(e) {
    obj[e[0]] = e[1];
  });
  return obj;
}

function basename(url) {
  url = url.substr(0, url.indexOf("?")) || url;
  url = url.substr(0, url.indexOf("#")) || url;
  return url.substr(url.lastIndexOf("/")+1);
}

$(document).ready(function() {
  window.dirty = 0;
  $(window).on("beforeunload", function(event) {
    if (window.dirty > 0) {
      event.returnValue = "There are still files downloading!";
      return event.returnValue;
    }
  });

  $(document).on("show.bs.dropdown", function(e) {
    form = $(e.target).parents("form");
    q = form.find("input[name=q]").val();
    form.find("[data-download]").each(function() {
      btn = $(this);
      url = `${form.attr("action")}/download?url=${q}`;
      val = btn.attr("data-download");
      if (val) {
        url += `&type=${val}`;
      }
      btn.attr("href", url);
    });
    form.find("[data-action]").each(function() {
      btn = $(this);
      btn.attr("href", `${form.attr("action")}/${btn.attr("data-action")}?url=${q}`);
    });
    form.find("[data-vlc]").each(function() {
      btn = $(this);
      btn.attr("href", `vlc://${form[0].action}/${btn.attr("data-vlc")}?url=${q}`);
    });
    form.find("[data-irc]").each(function() {
      btn = $(this);
      var m = /(?:https?:\/\/(?:www\.|clips\.)?twitch\.tv\/)?([^/]+)/.exec(q);
      if (m == null) {
        return;
      }
      var channel = m[1];
      btn.attr("href", `irc://${btn.attr("data-irc")}/${channel}`);
    });
  });

  $("[data-submit-type]").click(function() {
    var form = $(this).parents("form");
    var val = $(this).attr("data-submit-type");
    $('<input type="hidden" name="type">').val(val).insertAfter(this);
    if (form.attr("action") == "youtube") {
      $('<input type="hidden" name="tz">').val(-new Date().getTimezoneOffset()/60).insertAfter(this);
    }
    form.find("[type=submit]").click();
  });
  $(window).bind("pageshow", function() {
    $("[name=type]").detach(); // remove type inputs which remain when using the back button
  });

  $("[data-download-filename]").click(function() {
    var form = $(this).parents("form");
    var q = form.find("input[name=q]").val();
    if (q == "") {
      alert("Please enter a URL.");
      return;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.addEventListener("load", function() {
      var data = this.response;

      if (this.status != 200 || !data) {
        alert("Something went wrong.");
        return;
      }

      if (data.live) {
        $(`<div><p><tt>ffmpeg -i "${data.url}" "${data.filename}"</tt></p></div>`).insertAfter(form);
        return;
      }

      var progress = document.createElement("progress");
      $(progress).insertAfter(form);
      progress.title = data.filename;

      // this is a big hack for cross-origin <a download="filename">
      var xhr = new XMLHttpRequest();
      xhr.open("GET", data.url, true);
      xhr.responseType = "blob";
      var bigfile_warning = false;
      var chunk_size = 10000000;
      xhr.addEventListener("progress", function(e) {
        progress.value = e.loaded;
        progress.max = e.total;
        progress.title = `${fmt_filesize(e.loaded)} / ${fmt_filesize(e.total)} (${(e.loaded/e.total*100).toFixed(1)}%) of ${data.filename}`;
        if (e.total > 5*chunk_size && !bigfile_warning) {
          bigfile_warning = true;
          if (confirm(`This file is big (${fmt_filesize(e.total,0)}). Download with ${Math.ceil(e.total/chunk_size)} smaller and resumable requests instead?`)) {
            xhr.abort();
            $(progress).detach();
            var requests = [];
            for (var i=0, j=1; i < e.total; i += chunk_size, j++) {
              (function(i, j) {
                var progress = document.createElement("progress");
                $(progress).insertAfter(form);
                progress.title = data.filename;
                progress.value = 0;
                progress.max = 1;

                var xhr = new XMLHttpRequest();
                xhr.open("GET", data.url, true);
                xhr.responseType = "blob";
                xhr.setRequestHeader("Range", `bytes=${i}-${i+chunk_size-1}`);
                xhr.addEventListener("progress", function(e) {
                  if (e.total == 0) return;
                  progress.value = e.loaded;
                  progress.max = e.total;
                  progress.title = `Part ${j}: ${fmt_filesize(e.loaded)} / ${fmt_filesize(e.total)} (${(e.loaded/e.total*100).toFixed(1)}%) of ${data.filename}`;
                });
                xhr.addEventListener("error", function() {
                  console.log(`Network error downloading part ${j}.`);
                  // reuse xhr object and try again
                  var timer = setInterval(function() {
                    xhr.open("GET", data.url, true);
                    xhr.responseType = "blob";
                    xhr.setRequestHeader("Range", `bytes=${i}-${i+chunk_size-1}`);
                    try {
                      xhr.send();
                      clearInterval(timer);
                    }
                    catch (err) {
                      console.log(err);
                    }
                  }, 1000);
                });
                xhr.addEventListener("load", function() {
                  if (requests.every(function(request) {
                    return request.readyState == 4;
                  })) {
                    var parts = requests.map(function(request) {
                      return request.response;
                    });
                    var blob = new Blob(parts);
                    var url = window.URL.createObjectURL(blob);
                    var a = document.createElement("a");
                    a.style.display = "none";
                    a.href = url;
                    a.download = data.filename;
                    document.body.appendChild(a);
                    a.click();
                    setTimeout(function(){
                      document.body.removeChild(a);
                      window.URL.revokeObjectURL(url);
                      window.dirty--;
                    }, 100);
                  }
                });
                xhr.send();
                requests.push(xhr);
              })(i, j);
            }
          }
        }
      });
      xhr.addEventListener("error", function() {
        alert(`Network error downloading file:\n${data.filename}\n\nConsider opening the video and using the browser to download instead.`);
        window.dirty--;
      });
      xhr.addEventListener("load", function() {
        var blob = new Blob([xhr.response]);
        var url = window.URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.style.display = "none";
        a.href = url;
        a.download = data.filename;
        document.body.appendChild(a);
        a.click();
        setTimeout(function(){
          document.body.removeChild(a);
          window.URL.revokeObjectURL(url);
          window.dirty--;
        }, 100);
      });
      xhr.send();
      window.dirty++;
    });
    xhr.open("GET", `${form.attr("action")}/download?url=${q}`);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.send();
  });

  var params = toObject(window.location.search.substr(1).split("&").map(function(arg){ return arg.split("="); }));
  if (params.q) {
    $('input[type="search"]').val(params.q);
  }
});
