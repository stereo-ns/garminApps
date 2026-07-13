import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.Activity;
import Toybox.System;
import Toybox.Application;

(:glance)
class vo2GlanceView extends WatchUi.GlanceView {

    private const FORMAT_TWO_DECIMALS = "%.2f";
    private const NOT_AVAILABLE = "--";

    private const PADDING_X = 5;
    private const FONT_SIZE = Graphics.FONT_GLANCE;

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var profile = UserProfile.getProfile();
        var weightInGrams = profile.weight;
        
       // 1. ČITANJE VO2 MAX (Iz profila uređaja)
        var vo2MaxVal = null as Number?;
        
        if (profile != null) {
            if (profile.vo2maxCycling != null && profile.vo2maxCycling > 0) {
                vo2MaxVal = profile.vo2maxCycling;
            } else if (profile.vo2maxRunning != null && profile.vo2maxRunning > 0) {
                vo2MaxVal = profile.vo2maxRunning;
            }
        }

        // 2. ČITANJE FTP-A IZ KORISNIČKOG PROFILA SATA (CIQ 5.2.0 Automatsko rešenje)
        var ftpVal = null as Number?;
        
        if (profile != null) {
            if (profile has :functionalThresholdPower) {
                ftpVal = profile.functionalThresholdPower;
            } else if (profile has :ftp) {
                ftpVal = profile.ftp;
            }
        }

        // Ako sat još uvek nema ove registre, vučemo iz tvog settings.xml
        if (ftpVal == null) {
            try {
                ftpVal = Application.Properties.getValue("user_ftp") as Number;
            } catch(e) {
                ftpVal = 230; // Fallback default
            }
        }

        // 3. RENDER FORMATTING
        var vo2String = (vo2MaxVal != null) ? vo2MaxVal.toString() : NOT_AVAILABLE;
        var ftpString = ftpVal.toString() + "W";
        var wKgString = "";

        if (weightInGrams != null && weightInGrams > 0) {
            var weightKg = weightInGrams / 1000.0;
            var wattsPerKg = ftpVal.toFloat() / weightKg;
            wKgString = " (" + wattsPerKg.format(FORMAT_TWO_DECIMALS) + ")";
        }

        var totalHeight = dc.getHeight();
        var firstRowY = totalHeight * 0.25;  
        var secondRowY = totalHeight * 0.75; 

        var topRowText = "VO2 Max: " + vo2String;
        var bottomRowText = "FTP: " + ftpString + wKgString;

        dc.drawText(PADDING_X, firstRowY, FONT_SIZE, topRowText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(PADDING_X, secondRowY, FONT_SIZE, bottomRowText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
