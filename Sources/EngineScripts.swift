import Foundation

/// CSS/JS, die YouTube in eine reine Content-Fläche verwandeln.
enum EngineScripts {
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
    ytd-browse, ytd-search { padding-top: 30px !important; }
    #page-manager { padding-bottom: 80px !important; }
    ytd-feed-filter-chip-bar-renderer { background: transparent !important; }
    ::-webkit-scrollbar { display: none !important; }
    """#

    /// Wählt das aktive Video (bei Shorts das sichtbare).
    static let helper = #"""
    window.__ytmPick = function () {
      return document.querySelector('ytd-reel-video-renderer[is-active] video')
          || document.querySelector('video.html5-main-video')
          || document.querySelector('video');
    };
    """#

    /// Wird bei document-start in jede Seite injiziert.
    static let transform: String = {
        let literal = (try? JSONEncoder().encode(css)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return "(function(){ var s=document.createElement('style'); s.textContent=\(literal); (document.head||document.documentElement).appendChild(s); \(helper) })();"
    }()

    static let stateQuery = #"""
    (function(){
      var v = window.__ytmPick && window.__ytmPick();
      var t = document.title.replace(/^\(\d+\)\s*/, '').replace(/\s*-\s*YouTube$/, '');
      return JSON.stringify({title: t, hasVideo: !!v, playing: !!v && !v.paused && !v.ended});
    })()
    """#

    static let togglePlay = "var v=__ytmPick(); if(v){ if(v.paused){v.play();}else{v.pause();} }"

    static func seek(_ seconds: Double) -> String {
        "var v=__ytmPick(); if(v){ v.currentTime=Math.max(0, v.currentTime+(\(seconds))); }"
    }

    static let pip = #"""
    var v = __ytmPick();
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
