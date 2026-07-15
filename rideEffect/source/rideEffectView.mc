import Toybox.Activity;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.FitContributor;

class rideEffectView extends WatchUi.DataField {

    // --- COGGAN POWER ZONE MULTIPLERS ---
    private const ZONE_1_MAXIMUM_MULTIPLIER = 0.55;
    private const ZONE_2_MAXIMUM_MULTIPLIER = 0.75;
    private const ZONE_3_MAXIMUM_MULTIPLIER = 0.90;
    private const ZONE_4_MAXIMUM_MULTIPLIER = 1.05;

    // --- PHYSIOLOGICAL DIAGNOSIS DISTRIBUTION THRESHOLDS (%) ---
    private const THRESHOLD_DURATION_MIN_PERCENTAGE = 20.0;
    private const TEMPO_DURATION_MIN_PERCENTAGE = 35.0;
    private const BASE_DURATION_MIN_PERCENTAGE = 50.0;

    // --- FIT FILE DEVELOPER FIELD ---
    private const RIDE_DIAGNOSIS_FIELD_ID = 0;
    private var fitField = null;

    // --- REAL-TIME COUNTERS (SECONDS) ---
    private var z1Seconds as Number = 0;
    private var z2Seconds as Number = 0;
    private var z3Seconds as Number = 0;
    private var z4Seconds as Number = 0;
    private var z5PlusSeconds as Number = 0;
    private var totalSeconds as Number = 0;

    // --- SCREEN LAYOUT VARIABLES ---
    private var currentDiagnosis as String = "Go Legs!";
    private var intensityMetric as String = "";
    private var baseMetric as String = "";

    function initialize() {
        DataField.initialize();
        
        fitField = createField(
            "Session Profile", 
            RIDE_DIAGNOSIS_FIELD_ID, 
            FitContributor.DATA_TYPE_STRING, 
            { :count => 32, :mesgType => FitContributor.MESG_TYPE_SESSION }
        );
    }

    // Background mathematical core - executes strictly once per second
    function compute(info as Activity.Info) {
        var currentFtp = null;
        if (UserProfile has :getFunctionalThresholdPower) {
            var thresholdPower = UserProfile.getFunctionalThresholdPower(Activity.SPORT_CYCLING);
            if (thresholdPower != null && thresholdPower > 0) {
                currentFtp = thresholdPower.toFloat();
            }
        }

        if (currentFtp == null) {
            currentDiagnosis = "No FTP Profile";
            intensityMetric = "";
            baseMetric = "";
            return null;
        }

        if (info != null && info.currentPower != null) {
            var power = info.currentPower.toFloat();
            totalSeconds++;

            if (power > 0.0) {
                var z1Maximum = currentFtp * ZONE_1_MAXIMUM_MULTIPLIER;
                var z2Maximum = currentFtp * ZONE_2_MAXIMUM_MULTIPLIER;
                var z3Maximum = currentFtp * ZONE_3_MAXIMUM_MULTIPLIER;
                var z4Maximum = currentFtp * ZONE_4_MAXIMUM_MULTIPLIER;

                if (power <= z1Maximum) { z1Seconds++; }
                else if (power <= z2Maximum) { z2Seconds++; }
                else if (power <= z3Maximum) { z3Seconds++; }
                else if (power <= z4Maximum) { z4Seconds++; }
                else { z5PlusSeconds++; }
            }
        }

        if (totalSeconds == 0) { 
            currentDiagnosis = "Go Legs!";
            intensityMetric = "";
            baseMetric = "";
            return null; 
        }

        var totalSecsFloat = totalSeconds.toFloat();
        var z3Percentage = (z3Seconds.toFloat() / totalSecsFloat) * 100.0;
        var z4Percentage = (z4Seconds.toFloat() / totalSecsFloat) * 100.0;
        var z5PlusPercentage = (z5PlusSeconds.toFloat() / totalSecsFloat) * 100.0;

        var highIntensityPercentage = z3Percentage + z4Percentage + z5PlusPercentage;
        var baseIntensityPercentage = 100.0 - highIntensityPercentage;

        currentDiagnosis = calculateSessionProfile(z3Percentage, z4Percentage, z5PlusPercentage, highIntensityPercentage, baseIntensityPercentage);
        intensityMetric = "Intensity: " + highIntensityPercentage.toNumber() + "%";
        baseMetric = "Base: " + baseIntensityPercentage.toNumber() + "%";

        if (fitField != null) {
            fitField.setData(currentDiagnosis);
        }

        return null;
    }

    // Visual rendering engine - handles fonts and strict 3-line coordinate placements
    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        // Clear the canvas with native theme color palette (Light/Dark mode responsive)
        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();

        // Configure system brush to write clean contrast text
        var textColor = (getBackgroundColor() == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);

        if (intensityMetric.length() == 0) {
            // Render single motivational entry perfectly center-aligned using FONT_LARGE
            dc.drawText(centerX, height / 2, Graphics.FONT_LARGE, currentDiagnosis, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            // Render structured 3-line layout using massive fonts for extreme scannability
            var line1Y = (height * 0.22).toNumber(); // Upper line marker
            var line2Y = (height * 0.50).toNumber(); // Center line marker
            var line3Y = (height * 0.78).toNumber(); // Lower line marker

            // All lines are hardcoded to FONT_LARGE to prevent Garmin from shrinking the text
            dc.drawText(centerX, line1Y, Graphics.FONT_LARGE, currentDiagnosis, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(centerX, line2Y, Graphics.FONT_LARGE, intensityMetric, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(centerX, line3Y, Graphics.FONT_LARGE, baseMetric, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function calculateSessionProfile(z3Percentage as Float, z4Percentage as Float, z5PlusPercentage as Float, highIntensityPercentage as Float, baseIntensityPercentage as Float) as String {
        if (z4Percentage >= THRESHOLD_DURATION_MIN_PERCENTAGE || highIntensityPercentage > baseIntensityPercentage) {
            return "Threshold";
        }

        if (z3Percentage >= TEMPO_DURATION_MIN_PERCENTAGE || z3Percentage > baseIntensityPercentage) {
            return "Tempo / S.Spot";
        }

        if (baseIntensityPercentage >= BASE_DURATION_MIN_PERCENTAGE) {
            return "Aerobic Base";
        }

        return "Mixed Work";
    }
}
