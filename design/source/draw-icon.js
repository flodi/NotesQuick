// NotesQuick icon drawing engine — shared between the DC preview and the PNG export script.
// One source of truth so previews are pixel-identical to exported assets.
(function () {
  function rr(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  var BLUE_TOP = '#4F8BF0';
  var BLUE_BOT = '#1F5AC0';
  var LINE_BLUE = '#2F6FDD';
  var ORANGE = '#F5842A';

  // Draw the note glyph inside a tile at (ox,oy) of side T.
  // color: 'ink' -> white paper w/ blue lines ; if mono passes a single color it fills paper solid black w/ knocked-out lines.
  function drawGlyph(ctx, ox, oy, T, variant, mono) {
    var dw = T * 0.42;
    var dh = T * 0.52;
    var cx = ox + T / 2;
    var cy = oy + T / 2;
    var dx = cx - dw / 2;
    var dy = cy - dh / 2;
    var rad = dw * 0.13;

    function lines(px, py, pw, ph) {
      var n = 4;
      var lw = T * 0.030;
      var gap = ph * 0.205;
      var startY = py + ph * 0.17;
      var lens = [0.68, 0.68, 0.68, 0.42];
      ctx.lineCap = 'round';
      ctx.lineWidth = lw;
      for (var i = 0; i < n; i++) {
        var y = startY + gap * i;
        var x0 = px + pw * 0.16;
        var x1 = px + pw * 0.16 + pw * lens[i];
        ctx.strokeStyle = (variant === 'B' && i === 0) ? ORANGE : (mono ? '__KNOCK__' : LINE_BLUE);
        ctx.beginPath();
        ctx.moveTo(x0, y);
        ctx.lineTo(x1, y);
        ctx.stroke();
      }
    }

    if (mono) {
      // Solid paper, lines knocked out (transparent) via destination-out.
      rr(ctx, dx, dy, dw, dh, rad);
      ctx.fillStyle = '#000';
      ctx.fill();
      ctx.save();
      ctx.globalCompositeOperation = 'destination-out';
      var lw = T * 0.030, gap = dh * 0.205, startY = dy + dh * 0.17, lens = [0.68,0.68,0.68,0.42];
      ctx.lineCap = 'round'; ctx.lineWidth = lw; ctx.strokeStyle = '#000';
      for (var i = 0; i < 4; i++) {
        var y = startY + gap * i;
        ctx.beginPath();
        ctx.moveTo(dx + dw * 0.16, y);
        ctx.lineTo(dx + dw * 0.16 + dw * lens[i], y);
        ctx.stroke();
      }
      ctx.restore();
      return;
    }

    if (variant === 'C') {
      // Back sheet offset up-right.
      ctx.save();
      var off = T * 0.05;
      rr(ctx, dx + off, dy - off, dw, dh, rad);
      ctx.fillStyle = 'rgba(255,255,255,0.55)';
      ctx.fill();
      ctx.restore();
    }

    // Front paper
    ctx.save();
    if (variant === 'B') {
      ctx.shadowColor = 'rgba(10,30,70,0.35)';
      ctx.shadowBlur = T * 0.05;
      ctx.shadowOffsetY = T * 0.02;
    }
    rr(ctx, dx, dy, dw, dh, rad);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();
    ctx.restore();

    lines(dx, dy, dw, dh);
  }

  // Main entry. opts: { variant:'A'|'B'|'C', mac:bool, mono:bool }
  function drawNotesQuickIcon(ctx, size, opts) {
    opts = opts || {};
    var variant = opts.variant || 'A';
    ctx.clearRect(0, 0, size, size);

    if (opts.mono) {
      // Menu-bar template: black glyph on transparent. There is no colored tile
      // here, so the paper sheet IS the icon and must fill the canvas. drawGlyph
      // draws the paper at 42%x52% of its tile T (sized for the app icon), so we
      // pass an oversized T (paper height = T*0.52 ~= 0.82*size) to fill it out.
      var T = size * 1.58;
      drawGlyph(ctx, (size - T) / 2, (size - T) / 2, T, variant, true);
      return;
    }

    var ox = 0, oy = 0, T = size;
    if (opts.mac) {
      var pad = size * 0.095;
      ox = pad; oy = pad; T = size - pad * 2;
      // drop shadow for floating macOS tile
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,0.28)';
      ctx.shadowBlur = size * 0.03;
      ctx.shadowOffsetY = size * 0.012;
      rr(ctx, ox, oy, T, T, T * 0.225);
      ctx.fillStyle = BLUE_BOT;
      ctx.fill();
      ctx.restore();
      ctx.save();
      rr(ctx, ox, oy, T, T, T * 0.225);
      ctx.clip();
      paintTile(ctx, ox, oy, T, variant);
      ctx.restore();
    } else {
      // iOS/iPadOS full-bleed square (system applies the mask).
      paintTile(ctx, 0, 0, size, variant);
    }
    drawGlyph(ctx, ox, oy, T, variant);
  }

  function paintTile(ctx, ox, oy, T, variant) {
    var g = ctx.createLinearGradient(ox, oy, ox, oy + T);
    g.addColorStop(0, BLUE_TOP);
    g.addColorStop(1, BLUE_BOT);
    ctx.fillStyle = g;
    ctx.fillRect(ox, oy, T, T);
    if (variant === 'B') {
      // glossy top-left highlight
      var rg = ctx.createRadialGradient(ox + T * 0.28, oy + T * 0.20, 0, ox + T * 0.28, oy + T * 0.20, T * 0.9);
      rg.addColorStop(0, 'rgba(255,255,255,0.35)');
      rg.addColorStop(0.5, 'rgba(255,255,255,0.05)');
      rg.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.fillStyle = rg;
      ctx.fillRect(ox, oy, T, T);
    }
    if (variant === 'C') {
      // subtle vignette for depth
      var vg = ctx.createRadialGradient(ox + T / 2, oy + T / 2, T * 0.2, ox + T / 2, oy + T / 2, T * 0.75);
      vg.addColorStop(0, 'rgba(0,0,0,0)');
      vg.addColorStop(1, 'rgba(0,0,0,0.18)');
      ctx.fillStyle = vg;
      ctx.fillRect(ox, oy, T, T);
    }
  }

  window.drawNotesQuickIcon = drawNotesQuickIcon;
})();
