// Removes the loading screen once Flutter has drawn its first frame. Kept in
// a file (not inline) so the page works under a strict Content-Security-Policy.
window.addEventListener('flutter-first-frame', function () {
  var s = document.getElementById('splash');
  if (s) s.remove();
});
