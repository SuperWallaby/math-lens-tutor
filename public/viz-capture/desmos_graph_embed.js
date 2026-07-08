(function (global) {
  var DEMO_KEY = 'dcb31709b452b1cf9dc26972add0fda6';
  var TRIG_FNS = ['sin', 'cos', 'tan', 'sec', 'csc', 'cot', 'log', 'ln', 'sqrt'];
  var STATIC_PARAM_DEFAULTS = {
    a: 1, b: 0, c: 0, d: 0, e: 0, k: 1, m: 1, n: 1, p: 1, r: 1, t: 1,
  };
  var RESERVED = { x: 1, y: 1, e: 1, pi: 1 };
  var CALC_OPTIONS = {
    expressions: false,
    settingsMenu: false,
    zoomButtons: false,
    showResetButtonOnGraphpaper: false,
    lockViewport: true,
  };
  var GRID_STROKE = '#e8eaed';
  var AXIS_STROKE = '#d1d5db';

  var calc = null;
  var scriptLoading = null;

  function normalizeLogSubscripts(latex) {
    return String(latex || '').replace(
      /\blog_([0-9]+)\s*\(/gi,
      function (_, base) { return '\\log_{' + base + '}\\left('; },
    );
  }

  function normalizeAbsoluteValueBars(latex) {
    var s = String(latex || '');
    if (s.indexOf('|') === -1 || s.indexOf('\\left|') !== -1) return s;
    return s.replace(/\|([^|]+)\|/g, '\\left|$1\\right|');
  }

  function convertFunctionNotationToY(latex) {
    return String(latex || '').replace(
      /^([fgh]|f_[0-9]+|g_[0-9]+)\s*\(\s*x\s*\)\s*=/i,
      'y=',
    );
  }

  function normalizeFocusPointLabel(latex) {
    var s = String(latex || '').trim();
    var match = s.match(/^F_\d+\s*=\s*(\([^)]+\))\s*$/i);
    return match ? match[1] : s;
  }

  function substituteStaticParameters(latex) {
    return String(latex || '').replace(/\b([a-z])\b/gi, function (token, letter) {
      var key = String(letter).toLowerCase();
      if (RESERVED[key]) return token;
      if (!Object.prototype.hasOwnProperty.call(STATIC_PARAM_DEFAULTS, key)) return token;
      return String(STATIC_PARAM_DEFAULTS[key]);
    });
  }

  function normalizeDesmosLatex(latex) {
    var s = String(latex || '').trim();
    if (!s) return s;
    s = normalizeFocusPointLabel(s);
    s = convertFunctionNotationToY(s);
    s = normalizeLogSubscripts(s);
    s = normalizeAbsoluteValueBars(s);
    for (var i = 0; i < TRIG_FNS.length; i++) {
      var fn = TRIG_FNS[i];
      s = s.replace(
        new RegExp('\\b' + fn + '\\(([^()]*)\\)', 'g'),
        '\\' + fn + '\\left($1\\right)',
      );
    }
    return s;
  }

  function isPlottableDesmosExpression(line) {
    var s = String(line || '').trim();
    if (!s) return false;
    if (/\\lim[_\s{]/i.test(s) || /^lim[_\s(]/i.test(s)) return false;
    if (/\\to\b/i.test(s) && /lim/i.test(s)) return false;
    if (/^F_\d+\s*=/i.test(s)) return false;
    if (/^[A-Z]_\d+\s*=/.test(s)) return false;
    if (/^\d+\s*=\s*[-\d.]+\s*$/.test(s)) return false;
    return /=/.test(s) || /^\([^)]+\)$/.test(s);
  }

  function sanitizeDesmosExpression(latex) {
    return substituteStaticParameters(normalizeDesmosLatex(latex));
  }

  function sanitizeExpressionList(expressions, primary) {
    var primarySanitized = sanitizeDesmosExpression(primary);
    var extra = [];
    var seen = {};
    if (Array.isArray(expressions)) {
      expressions.forEach(function (item) {
        var sanitized = sanitizeDesmosExpression(item);
        if (!sanitized || seen[sanitized] || sanitized === primarySanitized) return;
        if (!isPlottableDesmosExpression(sanitized)) return;
        seen[sanitized] = true;
        extra.push(sanitized);
      });
    }
    return extra.length > 0 ? extra : undefined;
  }

  function applyEmbedSettings(c) {
    c.updateSettings({
      showGrid: true,
      xAxisMinorSubdivisions: 1,
      yAxisMinorSubdivisions: 1,
    });
  }

  function softenGraphChrome() {
    var root = document.getElementById('viz-root');
    if (!root) return;
    root.querySelectorAll('.dcg-graphpaper-grid line, .dcg-graphpaper-grid path').forEach(function (el) {
      el.setAttribute('stroke', GRID_STROKE);
      el.style.stroke = GRID_STROKE;
    });
    root.querySelectorAll('.dcg-xaxis line, .dcg-yaxis line').forEach(function (el) {
      el.setAttribute('stroke', AXIS_STROKE);
      el.style.stroke = AXIS_STROKE;
    });
  }

  function markReady() {
    global.__STUDY_VIZ_READY = true;
  }

  function waitForGraphSettled(c) {
    return new Promise(function (resolve) {
      var finished = false;
      var debounceTimer = null;
      var hardTimer = null;

      function finish() {
        if (finished) return;
        finished = true;
        if (debounceTimer) clearTimeout(debounceTimer);
        if (hardTimer) clearTimeout(hardTimer);
        softenGraphChrome();
        setTimeout(function () {
          softenGraphChrome();
          markReady();
          resolve();
        }, 450);
      }

      hardTimer = setTimeout(finish, 6000);
      try {
        c.observeEvent('change', function () {
          if (debounceTimer) clearTimeout(debounceTimer);
          debounceTimer = setTimeout(finish, 700);
        });
        debounceTimer = setTimeout(finish, 1200);
      } catch (e) {
        finish();
      }
    });
  }

  function ensureDesmos(apiKey) {
    if (typeof Desmos !== 'undefined') return Promise.resolve();
    if (scriptLoading) return scriptLoading;
    var key = (apiKey && String(apiKey).trim()) || DEMO_KEY;
    scriptLoading = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src =
        'https://www.desmos.com/api/v1.9/calculator.js?apiKey=' + encodeURIComponent(key);
      script.onload = function () { resolve(); };
      script.onerror = function () { reject(new Error('Desmos script failed')); };
      document.head.appendChild(script);
    });
    return scriptLoading;
  }

  function renderGraph(graphData) {
    var elt = document.getElementById('viz-root');
    if (!elt || typeof Desmos === 'undefined') {
      markReady();
      return Promise.resolve();
    }

    if (calc) {
      calc.destroy();
      calc = null;
    }

    calc = Desmos.GraphingCalculator(elt, CALC_OPTIONS);
    applyEmbedSettings(calc);

    var primary = sanitizeDesmosExpression(graphData.expression || 'y=x^2');
    var extra = sanitizeExpressionList(graphData.expressions, primary);
    calc.setExpression({ id: 'main', latex: primary });
    if (Array.isArray(extra)) {
      extra.forEach(function (latex, i) {
        calc.setExpression({ id: 'e' + i, latex: latex });
      });
    }

    if (graphData.xRange && graphData.yRange) {
      calc.setMathBounds({
        left: graphData.xRange[0],
        right: graphData.xRange[1],
        bottom: graphData.yRange[0],
        top: graphData.yRange[1],
      });
    }

    return waitForGraphSettled(calc);
  }

  function handleRender(graphData) {
    var apiKey = graphData && graphData.apiKey;
    return ensureDesmos(apiKey).then(function () {
      return renderGraph(graphData || {});
    }).catch(function () {
      markReady();
    });
  }

  function bootFromHash() {
    var raw = (location.hash || '').replace(/^#/, '');
    if (!raw) return false;
    try {
      raw = decodeURIComponent(raw);
      var bin = atob(raw);
      var u = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
      var graphData = JSON.parse(new TextDecoder('utf-8').decode(u));
      handleRender(graphData);
      return true;
    } catch (e) {
      markReady();
      return false;
    }
  }

  var params = new URLSearchParams(global.location.search);
  var preloadKey = params.get('apiKey');
  if (preloadKey) {
    ensureDesmos(preloadKey).catch(function () {});
  }

  setTimeout(function () {
    if (!global.__STUDY_VIZ_READY) markReady();
  }, 45000);

  if (!bootFromHash()) {
    markReady();
  }
})(window);
