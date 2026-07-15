import Toybox.Activity;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.FitContributor;

class rideEffectView extends WatchUi.DataField {

    // --- COGGAN POWER ZONE MULTIPLIERS ---
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

        // STRICT FILTER: Only run math and increment counters when the Garmin timer is explicitly ACTIVE
        if (info != null && info.timerState == Activity.TIMER_STATE_ON && info.currentPower != null) {
            var power = info.currentPower.toFloat();
            totalSeconds++; // Increments only when you are actively moving/recording

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
        
        // Full text labels without abbreviations as per your instructions
        intensityMetric = "Intensity: " + highIntensityPercentage.toNumber() + "%";
        baseMetric = "Base: " + baseIntensityPercentage.toNumber() + "%";

        if (fitField != null) {
            fitField.setData(currentDiagnosis);
        }

        return null;
    }

    // Dynamic visual rendering engine with text overlap protection (Layout 5b compatible)
    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();

        var textColor = (getBackgroundColor() == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);

        // AUTO-FONT RESIZING SYSTEM BASED ON THE ASSIGNED GRID BOX HEIGHT
        var fontToUse = Graphics.FONT_LARGE;
        if (height < 70) {
            fontToUse = Graphics.FONT_XTINY;
        } else if (height < 110) {
            fontToUse = Graphics.FONT_SMALL;
        } else if (height < 150) {
            fontToUse = Graphics.FONT_MEDIUM;
        }

        if (intensityMetric.length() == 0) {
            dc.drawText(centerX, height / 2, fontToUse, currentDiagnosis, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var line1Y, line2Y, line3Y;
            
            if (height < 90) {
                // Adaptive compressed positions for layouts like 5b
                line1Y = (height * 0.20).toNumber();
                line2Y = (height * 0.50).toNumber();
                line3Y = (height * 0.80).toNumber();
            } else {
                // Expanded standard spacing for full screen layouts
                line1Y = (height * 0.25).toNumber();
                line2Y = (height * 0.50).toNumber();
                line3Y = (height * 0.75).toNumber();
            }

            dc.drawText(centerX, line1Y, fontToUse, currentDiagnosis, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(centerX, line2Y, fontToUse, intensityMetric, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(centerX, line3Y, fontToUse, baseMetric, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
