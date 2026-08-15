function go(action) {
  parent.postMessage(
    JSON.stringify({ source: "wooyeol-pin", action: action }),
    "*"
  );
}
