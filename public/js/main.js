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
    btn = form.find("[data-download]");
    btn.attr("href", `${form.attr("action")}/download?url=${q}`);
  })

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

    var progress = document.createElement("progress");
    $(progress).insertAfter(form);

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.addEventListener("load", function() {
      // var data = JSON.parse(this.responseText);
      var data = this.response;
      progress.title = data.filename;

      // this is a big hack for cross-origin <a download="filename">
      var xhr = new XMLHttpRequest();
      xhr.open("GET", data.url, true);
      xhr.responseType = "blob";
      xhr.addEventListener("progress", function(e) {
        progress.value = e.loaded;
        progress.max = e.total;
        progress.title = `${fmt_filesize(e.loaded)} / ${fmt_filesize(e.total)} (${(e.loaded/e.total*100).toFixed(1)}%) of ${data.filename}`;
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
});
