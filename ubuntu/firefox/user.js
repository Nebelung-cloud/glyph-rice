// Glyph home page for Firefox: load userContent.css, strip the new tab page down to search + shortcuts.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", true);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.unifiedAds.spocs.enabled", false);
user_pref("browser.newtabpage.activity-stream.unifiedAds.tiles.enabled", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.system.showWeather", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.topSitesRows", 1);
user_pref("browser.newtabpage.activity-stream.newtabWallpapers.wallpaper", "");
user_pref("browser.newtabpage.activity-stream.newtabWallpapers.wallpaper-dark", "");
user_pref("browser.newtabpage.activity-stream.newtabWallpapers.wallpaper-light", "");
user_pref("browser.newtabpage.activity-stream.improvesearch.handoffToAwesomebar", true);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
