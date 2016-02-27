stateReady = $.Deferred()
docReady = $.Deferred()
currentApp = location.search.substr(1) || "home"
state = null

window.call = (method, args={}, reply=->) ->
  args["method"] = method
  chrome.runtime.sendMessage args, reply

$(document).ready ->
  $("#menu-edit").click (event) ->
    call "edit", app: currentApp

  $("#menu-editall").click (event) ->
    call "edit"

  $("#menu-reload").click (event) ->
    call "reload"
    setTimeout (-> window.location.reload()), 1000

  $("#menu-new").click (event) ->
    name = prompt("Name your new app:")
    unless name?
      return
    name = name.toLowerCase().replace(new RegExp(" ", 'g'), "")
    if name.length > 0
      call "newApp", name: name

  $("title").text(currentApp.charAt(0).toUpperCase()+currentApp.slice(1))

  docReady.resolve()

call "getState", null, (resp) ->
  state = resp
  if resp?
    localStorage.setItem("cache", JSON.stringify(resp))
  stateReady.resolve()

loadApp = (state, appName) ->
  frame = $("iframe").get(0)
  frame.src = "file://"+state.workspace+"/"+appName+"/index.html"
  call "watchApp", app: appName, (resp) ->
    console.log "[",appName,"]", "Reloading"
    loadApp state, appName

titleize = (s) ->
  if s.charAt(0) == "_"
    s = s.slice(1)
  s.charAt(0).toUpperCase()+s.slice(1)

activeClass = (name) ->
  if name == currentApp
    "active"
  else
    ""

$.when(docReady, stateReady).done ->
  unless state?
    state = JSON.parse localStorage.getItem("cache")
    console.log "Cached"
  else
    console.log "Ready"

  if state.apps?
    for name in state.apps
      if currentApp == name
        loadApp state, name
      if name == "home"
        continue
      if name.charAt(0) != "_"
        $("#menu-header").after(
          '<a href="?'+name+'" class="item '+activeClass(name)+'">'+titleize(name)+'</a>')
      else
        $(".menu.more").append(
          '<div class="item">
            <i class="dropdown icon"></i>
            '+titleize(name)+'
            <div class="menu">
              <a class="item" href="?'+name+'">Open</a>
              <a class="item more-edit" data-app="'+name+'" href="#">Edit</a>
            </div>
          </div>')
    $(".more-edit").click (e) -> call "edit", app: $(this).attr("data-app")

window.addEventListener "message", (msg) ->
  if msg.data.method == "reload"
    window.location.reload()
