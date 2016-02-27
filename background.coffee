rpc = new duplex.RPC(duplex.JSON)
bot = null
state = null
retry = null

api =
  connect: (args, reply) ->
    ws = new WebSocket("ws://localhost:11010/")
    ws.onopen = () ->
      rpc.handshake duplex.wrap.websocket(ws), (peer) ->
        bot = peer
        clearInterval(retry)
        reply()
    ws.onerror = (e) ->
      console.log e
      unless retry?
        alert("Error connecting with Deskbot. Retrying on 10s intervals.")
        retry = setInterval(api.connect, 10000)

  getState: (args, reply) ->
    reply(state)

  pickWorkspace: (args, reply) ->
    bot.call "files.pick", {directory: true}, (path) ->
      unless path?
        alert("No workspace path selected")
        return
      state.workspace = path
      state.save ->
        reply()

  reload: (args, reply) ->
    window.location.reload()

  reloadApps: (args, reply) ->
    bot.call "files.dirs", state.workspace, (apps) ->
      state.apps = apps
      state.save ->
        for app in state.apps
          jsFile = state.workspace+"/"+app+"/background.js"
          bot.call "files.read", path: jsFile, (js) ->
            if js?
              eval js
          coffeeFile = state.workspace+"/"+app+"/background.coffee"
          bot.call "files.read", path: coffeeFile, (coffee) ->
            if coffee?
              eval(CoffeeScript.compile(coffee))
        bot.call "files.watch", path: state.workspace, once: true, callback: rpc.callbackFunc ->
          api.reloadApps null, ->
            api.reloadTabs()
        reply()

  edit: (args, reply) ->
    path = state.workspace
    if args.app?
      path += "/"+args.app
    bot.call "editor.edit", filepath: path
    reply()

  newApp: (args, reply) ->
    path = state.workspace+"/"+args.name
    bot.call "files.mkdir", path, reply

  reloadTabs: (args, reply) ->
    tabs = chrome.extension.getViews type: "tab"
    for tab in tabs
      tab.postMessage method: "reload", "*"

  watchApp: (args, reply) ->
    bot.call "files.watch", path: state.workspace+"/"+args.app, once: true, callback: rpc.callbackFunc ->
      reply {}

botReady = new Promise (done, reject) ->
  api.connect(null, done)

stateReady = new Promise (done, reject) ->
  chrome.storage.local.get "state", (obj) ->
    obj.state = obj.state || {}
    obj.state.save = (cb) ->
      chrome.storage.local.set {"state": this}, cb
    state = obj.state
    done()

workspaceSetup = new Promise (done, reject) ->
  Promise.all([botReady, stateReady]).then ->
    bot.call "files.exists", state.workspace, (exists) ->
      if exists
        done()
      else
        api.pickWorkspace(null, done)

workspaceReady = new Promise (done, reject) ->
  workspaceSetup.then ->
    api.reloadApps(null, done)

chrome.runtime.onMessage.addListener (req, sndr, reply) ->
  if api[req.method]?
    api[req.method](req, reply)
    return true
  else
    reply error: "method not found"
