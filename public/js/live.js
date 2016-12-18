log=function(){};
// log=console.log;

var root_url = window.location.toString();
root_url = root_url.substr(0, root_url.lastIndexOf("/live"));

if (!localStorage.facebook) {
  localStorage.facebook = JSON.stringify({
    token: "",
    accounts: [],
  });
}
if (!localStorage.youtube) {
  localStorage.youtube = JSON.stringify({
    key: "",
    accounts: [],
  });
}
if (!localStorage.twitch) {
  localStorage.twitch = JSON.stringify({
    client_id: "",
    accounts: [],
  });
}
if (!localStorage.mute_notifications) {
  localStorage.mute_notifications = "false";
}

function add_commas(n) {
  return n.toString().replace(/(\d)(?=(\d{3})+($|,|\.))/g, "$1,");
}

function pad(n) {
  return `0${n}`.slice(-2);
}

function to_duration(t) {
  t = Math.round(t);
  var seconds = t % 60;
  var minutes = Math.floor(t / 60) % 60;
  var hours = Math.floor(t / 3600);
  if (hours > 0) {
    return `${hours}:${pad(minutes)}:${pad(seconds)}`;
  }
  else {
    return `${minutes}:${pad(seconds)}`;
  }
}

function toObject(arr) {
  var obj = {};
  arr.forEach(function(e) {
    obj[e[0]] = e[1];
  });
  return obj;
}

var notifications = [];
function notify(title, options) {
  var notification = new Notification(title, options);
  notifications.push(notification);
  notification.addEventListener("close", function(e) {
    notifications = notifications.filter(function(n) {
      return n != notification;
    });
  });
  return notification;
}

function update_accounts() {
  var facebook = JSON.parse(localStorage.facebook);
  var youtube = JSON.parse(localStorage.youtube);
  var twitch = JSON.parse(localStorage.twitch);

  $("#facebook_accounts").empty();
  facebook.accounts.forEach(function(a) {
    var panel = $(`
<div class="panel panel-default" data-facebook-id="${a.id}">
  <div class="panel-heading">
    ${a.username} (${a.id})
    <span class="label label-success hidden" data-live-label>live now</span>
    <button type="button" class="btn btn-xs btn-danger pull-right" data-facebook-id="${a.id}">Remove</button>
    <a class="btn btn-xs btn-default pull-right" href="https://www.facebook.com/${a.id}/videos">Open</a>
  </div>
  <div class="panel-body">
    <table class="table table-striped table-hover">
      <thead>
        <tr>
          <th class="fit">length</th>
          <th class="fit">status</th>
          <th>title</th>
          <th class="fit">date</th>
          <th class="fit"></th>
        </tr>
      </thead>
      <tbody data-facebook-id="${a.id}"></tbody>
    </table>
  </div>
</div>`);
    panel.find(".btn-danger").click(function() {
      var id = $(this).data("facebook-id");
      var facebook = JSON.parse(localStorage.facebook);
      facebook.accounts = facebook.accounts.filter(function(a) {
        return a.id != id;
      });
      localStorage.facebook = JSON.stringify(facebook);
      panel.detach();
    });
    $("#facebook_accounts").append(panel);
  });

  $("#youtube_accounts").empty();
  youtube.accounts.forEach(function(a) {
    var panel = $(`
<div class="panel panel-default" data-youtube-id="${a.id}">
  <div class="panel-heading">
    ${a.username} (${a.id})
    <span class="label label-success hidden" data-live-label>live now</span>
    <button type="button" class="btn btn-xs btn-danger pull-right" data-youtube-id="${a.id}">Remove</button>
    <a class="btn btn-xs btn-default pull-right" href="https://www.youtube.com/channel/${a.id}/live">Open</a>
  </div>
  <div class="panel-body">
    <table class="table table-striped table-hover">
      <thead>
        <tr>
          <th class="fit">status</th>
          <th>title</th>
          <th class="fit">date</th>
          <th class="fit">viewers</th>
        </tr>
      </thead>
      <tbody data-youtube-id="${a.id}"></tbody>
    </table>
  </div>
</div>`);
    panel.find(".btn-danger").click(function() {
      var id = $(this).data("youtube-id");
      var youtube = JSON.parse(localStorage.youtube);
      youtube.accounts = youtube.accounts.filter(function(a) {
        return a.id != id;
      });
      localStorage.youtube = JSON.stringify(youtube);
      panel.detach();
    });
    $("#youtube_accounts").append(panel);
  });

  $("#twitch_accounts").empty();
  twitch.accounts.forEach(function(a) {
    var panel = $(`
<div class="panel panel-default" data-twitch-id="${a.id}">
  <div class="panel-heading">
    ${a.display_name}
    <span class="label label-success hidden" data-live-label>live now</span>
    <button type="button" class="btn btn-xs btn-danger pull-right" data-twitch-id="${a.id}">Remove</button>
    <a class="btn btn-xs btn-default pull-right" href="irc://irc.chat.twitch.tv:6667/${a.username}" target="_self">IRC</a>
    <a class="btn btn-xs btn-default pull-right" href="https://www.twitch.tv/${a.username}">Open</a>
  </div>
  <div class="panel-body">
    <table class="table table-striped table-hover">
      <thead>
        <tr>
          <th class="fit">length</th>
          <th class="fit">status</th>
          <th>title</th>
          <th class="fit">game</th>
          <th class="fit">date</th>
          <th class="fit"></th>
        </tr>
      </thead>
      <tbody data-twitch-id="${a.id}"></tbody>
    </table>
  </div>
</div>`);
    panel.find(".btn-danger").click(function() {
      var id = $(this).data("twitch-id");
      var twitch = JSON.parse(localStorage.twitch);
      twitch.accounts = twitch.accounts.filter(function(a) {
        return a.id != id;
      });
      localStorage.twitch = JSON.stringify(twitch);
      panel.detach();
    });
    $("#twitch_accounts").append(panel);
  });
}

function poll() {
  // var progress = $("#progress")[0];
  // progress.style.transition = "";
  // progress.style.width = "0";
  // setTimeout(function() {
  //   progress.style.transition = "all 29500ms linear";
  //   progress.style.width = "100%";
  // }, 300);

  var facebook = JSON.parse(localStorage.facebook);
  if (facebook.accounts.length > 0) {
    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("POST", "https://graph.facebook.com/v2.8");
    xhr.addEventListener("load", function() {
      this.response.forEach(function(r, i) {
        var a = facebook.accounts[i];
        if (r.code != 200) {
          log(r);
          return;
        }
        var data = JSON.parse(r.body).data;
        var videos = data.filter(function(v){ return v.live_status }).slice(0, 3);
        log("facebook", a.username, new Date, videos);
        videos.slice().reverse().forEach(function(v) {
          var tbody = $(`tbody[data-facebook-id="${a.id}"]`);
          var tr_id = `${v.live_status}-${v.id}`;
          if (tbody.find(`#${tr_id}`).length > 0) {
            return;
          }
          var tr = $(`
<tr id="${tr_id}">
  <td class="fit">${to_duration(v.length)}</td>
  <td class="fit">${v.live_status}</td>
  <td><a href="https://www.facebook.com/video/embed?video_id=${v.id}">${v.description || "Untitled"}</a></td>
  <td class="fit"><time class="timeago" datetime="${v.created_time}">${v.created_time.replace("T"," ").replace("+"," +")}</time></td>
  <td class="fit"><a class="btn btn-xs btn-default" href="vlc://https://www.facebook.com/video/playback/playlist.m3u8?v=${videos[0].id}&q=HD" target="_self">VLC</a></td>
</tr>`);
          tbody.prepend(tr);
          if ($("#mute_notifications").prop("checked")) {
            return;
          }
          if (v.live_status == "LIVE") {
            var notification = notify(`${v.from.name} is live on Facebook`, {
              body: `Started ${$.timeago(v.created_time)}.\n${v.description || ""}`,
              icon: `https://graph.facebook.com/${a.id}/picture`,
            });
            notification.addEventListener("click", function(e) {
              notification.close();
              window.focus();
              tr.addClass("success");
              tbody.parents("div.panel")[0].scrollIntoView();
            });
          }
        });
        if (videos.some(function(v) { return v.live_status == "LIVE" })) {
          $(`div[data-facebook-id="${a.id}"] [data-live-label]`).removeClass("hidden");
        }
        else {
          $(`div[data-facebook-id="${a.id}"] [data-live-label]`).addClass("hidden");
        }
      });
      $("time.timeago").timeago();
    });
    var form = new FormData();
    form.append("access_token", facebook.token);
    form.append("batch", JSON.stringify(facebook.accounts.map(function(a) {
      return {
        method: "GET",
        relative_url: `${a.id}/videos?fields=created_time,from,title,description,embeddable,embed_html,length,live_status`,
      };
    })));
    xhr.send(form);
  }

  var youtube = JSON.parse(localStorage.youtube);
  youtube.accounts.forEach(function(a) {
    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://www.googleapis.com/youtube/v3/search?part=id&type=video&order=date&eventType=live&channelId=${a.id}&key=${youtube.key}`);
    xhr.addEventListener("load", function() {
      var ids = this.response.items.map(function(v) { return v.id.videoId });
      var xhr2 = new XMLHttpRequest();
      xhr2.responseType = "json";
      xhr2.open("GET", `https://www.googleapis.com/youtube/v3/videos?part=snippet,liveStreamingDetails&id=${ids.join(",")}&key=${youtube.key}`);
      xhr2.addEventListener("load", function() {
        log("youtube", a.username, new Date, this.response.items);
        var tbody = $(`tbody[data-youtube-id="${a.id}"]`);
        this.response.items.slice().reverse().forEach(function(v) {
          var live_status, live_text, notification_text;
          if (v.liveStreamingDetails) {
            if (v.liveStreamingDetails.actualEndTime) {
              live_status = "ended";
              live_text = `ended <time class="timeago" datetime="${v.liveStreamingDetails.actualEndTime}">${v.liveStreamingDetails.actualEndTime.replace("T"," ")}</time>`;
            }
            else if (v.liveStreamingDetails.actualStartTime) {
              live_status = "live";
              live_text = `started <time class="timeago" datetime="${v.liveStreamingDetails.actualStartTime}">${v.liveStreamingDetails.actualStartTime.replace("T"," ")}</time>`;
              notification_text = `Started ${$.timeago(v.liveStreamingDetails.actualStartTime)}\n${v.snippet.title}`;
            }
            else if (v.liveStreamingDetails.scheduledStartTime) {
              live_status = "scheduled";
              live_text = `scheduled to start <time class="timeago"; datetime="${v.liveStreamingDetails.scheduledStartTime}">${v.liveStreamingDetails.scheduledStartTime.replace("T"," ")}</time>`;
            }
          }
          var concurrent_viewers = v.liveStreamingDetails.concurrentViewers ? `${add_commas(v.liveStreamingDetails.concurrentViewers)} viewers` : "not live";
          var tr_id = `youtube-${live_status}-${v.id}`;
          if (tbody.find(`#${tr_id}`).length > 0) {
            $(`#${tr_id} > td[data-concurrent-viewers]`).text(concurrent_viewers);
            return;
          }
          var tr = $(`
<tr id="${tr_id}">
  <td class="fit">${live_status}</td>
  <td><a href="https://www.youtube.com/watch?v=${v.id}">${v.snippet.title}</a></td>
  <td class="fit">${live_text}</td>
  <td class="fit" data-concurrent-viewers>${concurrent_viewers}</td>
</tr>`);
          tbody.prepend(tr);
          if ($("#mute_notifications").prop("checked")) {
            return;
          }
          if (live_status == "live") {
            var notification = notify(`${v.snippet.channelTitle} is live on YouTube`, {
              body: notification_text,
              icon: v.snippet.thumbnails.default.url,
            });
            notification.addEventListener("click", function(e) {
              notification.close();
              window.focus();
              tr.addClass("success");
              tbody.parents("div.panel")[0].scrollIntoView();
            });
          }
        });
        if (this.response.items.some(function(v) { return v.liveStreamingDetails && v.liveStreamingDetails.actualStartTime && !v.liveStreamingDetails.actualEndTime })) {
          $(`div[data-youtube-id="${a.id}"] [data-live-label]`).removeClass("hidden");
        }
        else {
          $(`div[data-youtube-id="${a.id}"] [data-live-label]`).addClass("hidden");
        }
        $("time.timeago").timeago();
      });
      xhr2.send();
    });
    xhr.send();
  });

  var twitch = JSON.parse(localStorage.twitch);
  twitch.accounts.forEach(function(a) {
    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://api.twitch.tv/kraken/channels/${a.username}/videos?broadcast_type=all`);
    xhr.setRequestHeader("Accept", "application/vnd.twitchtv.v3+json");
    xhr.setRequestHeader("Client-ID", twitch.client_id);
    xhr.addEventListener("load", function() {
      var videos = this.response.videos.slice(0, 3);
      log("twitch", a.username, new Date, videos);
      var tbody = $(`tbody[data-twitch-id="${a.id}"]`);
      videos.slice().reverse().forEach(function(v) {
        var tr_id = `twitch-${v.status}-${v._id}`;
        if (tbody.find(`#${tr_id}`).length > 0) {
          return;
        }
        var url = v.url;
        if (v.status == "recording") {
          url = `https://www.twitch.tv/${a.username}`;
        }
        var tr = $(`
<tr id="${tr_id}">
  <td>${to_duration(v.length)}</td>
  <td>${v.status}</td>
  <td><a href="${url}">${v.title}</a></td>
  <td class="fit">${v.game || "N/A"}</td>
  <td><time class="timeago" datetime="${v.created_at}">${v.created_at.replace("T"," ")}</time></td>
  <td><a class="btn btn-xs btn-default" href="vlc://${root_url}/twitch/watch?url=${v.status == "recording" ? a.username : v._id}" target="_self">VLC</a></td>
</tr>`);
        tbody.prepend(tr);
        if ($("#mute_notifications").prop("checked")) {
          return;
        }
        if (v.status == "recording") {
          var notification = notify(`${v.channel.display_name} is ${v.game ? `playing ${v.game}` : "live on Twitch"}`, {
            body: `Started ${$.timeago(v.created_at)}.\n${v.title}`,
            icon: v.thumbnails.length > 0 ? v.thumbnails[0].url : `https://static-cdn.jtvnw.net/ttv-boxart/${encodeURIComponent(v.game)}-138x190.jpg`,
          });
          notification.addEventListener("click", function(e) {
            notification.close();
            window.focus();
            tr.addClass("success");
            tbody.parents("div.panel")[0].scrollIntoView();
          });
        }
      });
      if (videos.some(function(v) { return v.status == "recording" })) {
        $(`div[data-twitch-id="${a.id}"] [data-live-label]`).removeClass("hidden");
      }
      else {
        $(`div[data-twitch-id="${a.id}"] [data-live-label]`).addClass("hidden");
      }
      $("time.timeago").timeago();
    });
    xhr.send();
  });

  $("#counter").text(parseInt($("#counter").text(),10)+1);
  $("#last_updated").text(new Date);
}

$(document).ready(function() {
  $.timeago.settings.allowFuture = true;
  update_accounts();
  $("#mute_notifications").prop("checked", JSON.parse(localStorage.mute_notifications));
  $("#mute_notifications").change(function() {
    localStorage.mute_notifications = JSON.stringify(this.checked);
    if (this.checked) {
      notifications.forEach(function(notification) {
        notification.close();
      });
    }
  });

  $("#facebook_form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    setTimeout(function() {
      form.removeClass("has-success has-error");
    }, 3000);
    var q = $("#facebook_q").val();
    var facebook = JSON.parse(localStorage.facebook);

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://graph.facebook.com/v2.8/${q}?fields=username&access_token=${facebook.token}`);
    xhr.addEventListener("load", function() {
      var data = this.response;
      if (this.response.error) {
        form.addClass("has-error");
        alert(this.response.error.message);
        return;
      }
      if (facebook.accounts.find(function(a){ return a.id == data.id })) {
        alert("You are already monitoring this page.");
        return;
      }
      facebook.accounts.push(data);
      localStorage.facebook = JSON.stringify(facebook);
      form.addClass("has-success");
      update_accounts();
    });
    xhr.send();
  });

  $("#youtube_form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    setTimeout(function() {
      form.removeClass("has-success has-error");
    }, 3000);
    var q = $("#youtube_q").val();
    var youtube = JSON.parse(localStorage.youtube);

    var url, re;
    if (re=/(?:UC|S)[0-9a-zA-Z]{22}/.exec(q)) {
      url = `https://www.googleapis.com/youtube/v3/channels?part=snippet&id=${re[0]}&key=${youtube.key}`;
    }
    else {
      url = `https://www.googleapis.com/youtube/v3/channels?part=snippet&forUsername=${q}&key=${youtube.key}`;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", url);
    xhr.addEventListener("load", function() {
      if (this.response.items.length == 0) {
        form.addClass("has-error");
        alert("Could not find a channel with that name.");
        return;
      }
      var data = this.response.items[0];
      var acc = {
        id: data.id,
        username: data.snippet.title,
      };

      if (youtube.accounts.find(function(a){ return a.id == acc.id })) {
        alert("You are already monitoring this channel.");
        return;
      }
      youtube.accounts.push(acc);
      localStorage.youtube = JSON.stringify(youtube);
      form.addClass("has-success");
      update_accounts();
    });
    xhr.send();
  });

  $("#twitch_form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    setTimeout(function() {
      form.removeClass("has-success has-error");
    }, 3000);
    var q = $("#twitch_q").val();
    if (re=/twitch\.tv\/([^\/?#]+)/.exec(q)) {
      q = re[1];
    }
    var twitch = JSON.parse(localStorage.twitch);

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://api.twitch.tv/kraken/channels/${q}`);
    xhr.setRequestHeader("Accept", "application/vnd.twitchtv.v3+json");
    xhr.setRequestHeader("Client-ID", twitch.client_id);
    xhr.addEventListener("load", function() {
      if (this.response.error) {
        form.addClass("has-error");
        alert(this.response.message || this.response.error);
        return;
      }
      var data = this.response;
      var acc = {
        id: data._id,
        username: data.name,
        display_name: data.display_name,
      };

      if (twitch.accounts.find(function(a){ return a.id == acc.id })) {
        alert("You are already monitoring this channel.");
        return;
      }
      twitch.accounts.push(acc);
      localStorage.twitch = JSON.stringify(twitch);
      form.addClass("has-success");
      update_accounts();
    });
    xhr.send();
  });
  $("#twitch-import-modal").on("show.bs.modal", function(event) {
    var modal = $(this);
    var q = $("#twitch_q").val();
    if (q) {
      var input = modal.find("input[type='search']");
      input.val(q);
      modal.find("form").submit();
    }
  });
  $("#twitch-import-select-all").click(function() {
    var list = $("#twitch-import-list");
    list.find("input:enabled").prop("checked", list.find("input:enabled:not(:checked)").length != 0).change();
  });
  $("#twitch-import-modal form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    var q = form.find("input[type='search']").val();
    var submit = form.find("button[type='submit']");
    var modal = form.parents(".modal");
    var add_button = modal.find(".btn-primary");
    var list = modal.find("#twitch-import-list");
    list.html(`<span class="glyphicon glyphicon-refresh spin"></span> Loading...`);
    submit.prop("disabled", true);
    add_button.prop("disabled", true);

    var twitch = JSON.parse(localStorage.twitch);
    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://api.twitch.tv/kraken/users/${encodeURIComponent(q)}/follows/channels`);
    xhr.setRequestHeader("Accept", "application/vnd.twitchtv.v3+json");
    xhr.setRequestHeader("Client-ID", twitch.client_id);
    xhr.addEventListener("load", function() {
      submit.prop("disabled", false);
      if (this.status == 404) {
        list.text(`The user ${q} does not exist.`);
        return;
      }
      if (this.status != 200) {
        list.text(`Error ${this.status}.`);
        return;
      }
      if (this.response.follows.length == 0) {
        list.text("This user is not following anyone.");
      }
      var ul = $("<ul></ul>");
      list.empty();
      list.append(ul);
      this.response.follows.sort(function(a,b) {
        return a.channel.name.localeCompare(b.channel.name);
      }).forEach(function(follow) {
        var li = $(`<li class="checkbox"><label><input type="checkbox"></label></li>`)
        var checkbox = li.find("input");
        checkbox.val(JSON.stringify({
          id: follow.channel._id,
          username: follow.channel.name,
          display_name: follow.channel.display_name,
        }));
        if (twitch.accounts.some(function(a) { return a.id == follow.channel._id })) {
          checkbox.prop("disabled", true).prop("checked", true);
        }
        li.find("label").append(document.createTextNode(" "+follow.channel.display_name))
        li.append(" ");
        li.append($('<a target="_blank"><span class="glyphicon glyphicon glyphicon-new-window"></span></a>').prop("href", `https://www.twitch.tv/${follow.channel.name}`));
        ul.append(li);
      });
      list.find("input").on("change", function() {
        add_button.prop("disabled", ul.find("input:enabled:checked").length == 0);
      });
    });
    xhr.addEventListener("error", function() {
      submit.prop("disabled", false);
      list.text(`Error ${this.status}.`);
    });
    xhr.send();
  });
  $("#twitch-import-modal .btn-primary").click(function() {
    var modal = $(this).parents(".modal");
    var list = modal.find("#twitch-import-list");
    var twitch = JSON.parse(localStorage.twitch);
    list.find("input:checked:enabled").each(function(i, input) {
      var a = JSON.parse(input.value);
      twitch.accounts.push(a);
    });
    localStorage.twitch = JSON.stringify(twitch);
    modal.modal("toggle");
    update_accounts();
  });

  $("#facebook_token").parents("form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    var token = $("#facebook_token").val();

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://graph.facebook.com/v2.8/debug_token?input_token=${token}&access_token=${token}`);
    xhr.addEventListener("load", function() {
      if (this.response.error) {
        form.addClass("has-error");
        alert(this.response.error.message);
        return;
      }
      var data = this.response.data;
      if (!data.is_valid) {
        form.addClass("has-error");
        alert("This token is not valid.");
        return;
      }
      var facebook = JSON.parse(localStorage.facebook);
      facebook.token = token;
      localStorage.facebook = JSON.stringify(facebook);
      form.addClass("has-success");
    });
    xhr.send();
  });
  $("#facebook_token").on("input", function(e) {
    $(this.form).removeClass("has-success has-error");
  });
  var facebook = JSON.parse(localStorage.facebook);
  if (facebook.token) {
    $("#facebook_token").val(facebook.token);
  }

  $("#youtube_key").parents("form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    var key = $("#youtube_key").val();

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://www.googleapis.com/youtube/v3/videos?part=snippet&id=9bZkp7q19f0&key=${key}`);
    xhr.addEventListener("load", function() {
      if (this.response.error) {
        form.addClass("has-error");
        alert(this.response.error.errors[0].reason);
        return;
      }
      var youtube = JSON.parse(localStorage.youtube);
      youtube.key = key;
      localStorage.youtube = JSON.stringify(youtube);
      form.addClass("has-success");
    });
    xhr.send();
  });
  $("#youtube_key").on("input", function(e) {
    $(this.form).removeClass("has-success has-error");
  });
  var youtube = JSON.parse(localStorage.youtube);
  if (youtube.key) {
    $("#youtube_key").val(youtube.key);
  }

  $("#twitch_client_id").parents("form").submit(function(e) {
    e.preventDefault();
    var form = $(this);
    var client_id = $("#twitch_client_id").val();

    var xhr = new XMLHttpRequest();
    xhr.responseType = "json";
    xhr.open("GET", `https://api.twitch.tv/kraken/base`);
    xhr.setRequestHeader("Accept", "application/vnd.twitchtv.v3+json");
    xhr.setRequestHeader("Client-ID", client_id);
    xhr.addEventListener("load", function() {
      if (this.response.error) {
        form.addClass("has-error");
        alert(this.response.message);
        return;
      }
      var twitch = JSON.parse(localStorage.twitch);
      twitch.client_id = client_id;
      localStorage.twitch = JSON.stringify(twitch);
      form.addClass("has-success");
    });
    xhr.send();
  });
  $("#twitch_client_id").on("input", function(e) {
    $(this.form).removeClass("has-success has-error");
  });
  var twitch = JSON.parse(localStorage.twitch);
  if (twitch.client_id) {
    $("#twitch_client_id").val(twitch.client_id);
  }

  $("#export_settings").click(function(e) {
    var obj = {};
    Object.keys(window.localStorage).sort().forEach(function(key) {
      if (["better_errors_previous_commands"].indexOf(key) != -1) return;
      obj[key] = JSON.parse(window.localStorage[key]);
    });
    $("#settings").val(JSON.stringify(obj));
  });
  $("#import_settings").parents("form").submit(function(e) {
    e.preventDefault();
    try {
      var settings = JSON.parse($(this).find("textarea").val());
    } catch (err) {
      alert("Error parsing JSON.");
      return;
    }
    Object.keys(settings).forEach(function(key) {
      window.localStorage[key] = JSON.stringify(settings[key]);
    });
    alert("Settings imported. You should reload the page now.");
  });
  $("#clear_settings").click(function(e) {
    if (!confirm("This will clear all your settings and reload the page. Are you sure you want to do this?")) {
      return;
    }
    Object.keys(window.localStorage).forEach(function(key) {
      delete window.localStorage[key];
    });
    window.location.reload();
  });

  setInterval(poll, 30000);
  poll();

  var params = toObject(window.location.search.substr(1).split("&").map(function(arg){ return arg.split("="); }));
  if (params.q) {
    $('#submit_section input[type="search"]').val(params.q);
  }

  log(`Notification permissions: ${Notification.permission}`);
  if (Notification.permission !== "granted") {
    Notification.requestPermission();
  }

  $(window).on("beforeunload", function(event) {
    notifications.forEach(function(notification) {
      notification.close();
    });
  });
});
