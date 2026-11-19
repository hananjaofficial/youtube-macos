import Foundation

/// CSS/JS für die Web-Engine: Transparenz, Player-Steuerung.
enum EngineScripts {
    /// Nur für YouTube: transparent, ohne Kopfzeile und Seitenleiste.
    static let css = #"""
    html, body, ytd-app, #content, ytd-page-manager, ytd-browse, ytd-search, ytd-watch-flexy,
    #columns, #primary, #secondary, ytd-two-column-browse-results-renderer {
      background: transparent !important;
    }
    html {
      --yt-spec-base-background: transparent !important;
      --yt-spec-general-background-a: transparent !important;
      --yt-spec-general-background-b: transparent !important;
      --ytd-masthead-height: 0px !important;
      --ytd-mini-guide-width: 0px !important;
    }
    ytd-masthead, #masthead-container, tp-yt-app-drawer, #guide,
    ytd-mini-guide-renderer, #guide-button, ytd-searchbox {
      display: none !important;
    }
    ytd-page-manager { margin-top: 0 !important; margin-left: 0 !important; }
    ytd-feed-filter-chip-bar-renderer { background: transparent !important; }
    ::-webkit-scrollbar { display: none !important; }
    """#

    /// Wählt das aktive Video (YouTube, Instagram, TikTok).
    static let helper = #"""
    window.__hpPick = function () {
      var a = document.querySelector('ytd-reel-video-renderer[is-active] video');
      if (a) { return a; }
      var vs = Array.prototype.slice.call(document.querySelectorAll('video'));
      if (!vs.length) { return null; }
      var playing = vs.filter(function (v) { return !v.paused && !v.ended; });
      if (playing.length) { return playing[0]; }
      var mid = window.innerHeight / 2, best = null, bd = 1e9;
      vs.forEach(function (v) {
        var r = v.getBoundingClientRect();
        var d = Math.abs((r.top + r.bottom) / 2 - mid);
        if (d < bd) { bd = d; best = v; }
      });
      return best;
    };
    """#

    /// Wird bei document-start in jede Seite injiziert.
    static let transform: String = {
        let literal = (try? JSONEncoder().encode(css)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return "(function(){\n" + helper
            + "\nif (/(^|\\.)youtube\\.com$/.test(location.hostname)) {"
            + " var s=document.createElement('style'); s.textContent=\(literal);"
            + " (document.head||document.documentElement).appendChild(s); }\n})();"
    }()

    static let stateQuery = #"""
    (function(){
      var v = window.__hpPick && window.__hpPick();
      return JSON.stringify({hasVideo: !!v, playing: !!v && !v.paused && !v.ended});
    })()
    """#

    static let togglePlay = "var v=__hpPick(); if(v){ if(v.paused){v.play();}else{v.pause();} }"
    static let pause = "var v=__hpPick(); if(v && !v.paused){ v.pause(); }"

    static func seek(_ seconds: Double) -> String {
        "var v=__hpPick(); if(v){ v.currentTime=Math.max(0, v.currentTime+(\(seconds))); }"
    }

    static let pip = #"""
    var v = __hpPick();
    if (v) {
      v.disablePictureInPicture = false;
      if (document.pictureInPictureElement) { document.exitPictureInPicture(); }
      else if (v.requestPictureInPicture) { v.requestPictureInPicture(); }
      else if (v.webkitSetPresentationMode) {
        v.webkitSetPresentationMode(v.webkitPresentationMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture');
      }
    }
    """#
}
