// ==UserScript==
// @name        Disable Squarespace Login
// @namespace   https://github.com/Dan-Albrecht/miscellaneous
// @match       *://*/*
// @grant       none
// @version     0.9
// @author      Dan Albrecht
// @description 12/2/2022, 8:50:35 PM
// ==/UserScript==

if (typeof (Static) !== 'undefined') {
  if (Static?.SQUARESPACE_CONTEXT?.websiteSettings?.useEscapeKeyToLogin === true) {
    Static.SQUARESPACE_CONTEXT.websiteSettings.useEscapeKeyToLogin = false
    console.log('disabled login')
  } else {
    console.log('login hook was not on')
  }
} else {
  console.log('not a square site')
}
