import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let config = Config.load()
let controller = StatusBarController(config: config)
_ = controller

app.run()
