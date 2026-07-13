import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class vo2GlanceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        return [ new vo2FullView() ];
    }

    (:glance)
    function getGlanceView() {
        return [ new vo2GlanceView() ];
    }

    // IZMENA: Okidač koji osvežava aplikaciju čim promeniš FTP u podešavanjima
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

function getApp() as vo2GlanceApp {
    return Application.getApp() as vo2GlanceApp;
}