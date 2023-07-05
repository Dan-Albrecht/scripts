// ==UserScript==
// @name        Redirect To Old Reddit
// @namespace   https://github.com/Dan-Albrecht/scripts
// @match       https://www.reddit.com/*
// @run-at      document-start
// @grant       none
// @version     1.0
// @author      Dan Albrecht
// @description Redirects to old reddit
// ==/UserScript==

if (window.top === window.self) {
  // Seems like we're sometimes getting triggered without respect to the match, so double check we're not going to end up in a loop or something
  var expectedOrigin = "https://www.reddit.com"
  if (window.self.location.origin === expectedOrigin) {
    if (window.self.location.pathname !== null && (window.self.location.pathname.startsWith("/gallery/") || window.self.location.pathname === "/gallery")) {
      console.log("No Old reddit site for galleries :'(")
    } else {
      var old = window.self.location.toString().replace(window.self.location.origin, "https://old.reddit.com")
      window.self.location.replace(old)
    }
  } else {
    console.error('Script triggered for origin ' + window.self.location.origin + ' but it is only expected to match ' + expectedOrigin)
  }
}
