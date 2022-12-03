// ==UserScript==
// @name        Disable Squarespace Login
// @namespace   https://github.com/Dan-Albrecht/miscellaneous
// @match       *://*/*
// @grant       none
// @version     1.0
// @author      Dan Albrecht
// @description Disables the horribly annoying behavior of Squarespace sites redirecting to the login page on the press of the escape key. 
// ==/UserScript==

if (typeof (Static) !== 'undefined') {
  if (Static?.SQUARESPACE_CONTEXT?.websiteSettings?.useEscapeKeyToLogin === true) {
    Static.SQUARESPACE_CONTEXT.websiteSettings.useEscapeKeyToLogin = false
  }
}
