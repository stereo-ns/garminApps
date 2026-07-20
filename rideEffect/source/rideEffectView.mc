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

    // --- ENUM ZA PROFILE ---
    enum SessionProfile {
        GO_LEGS,
        NO_FTP,
        THRESHOLD,
        TEMPO_SS,
        AEROBIC_BASE,
        MIXED_WORK
    }

    // --- KEŠIRANI STRINGOVI ZA MAKSIMALNU BRZINU ---
    private var _cachedDisplayStrings as Array<String> = [] as Array<String>;
    private var _cachedFitStrings as Array<String> = ["Go Legs!", "No FTP Profile", "Threshold", "Tempo / S.Spot", "Aerobic Base", "Mixed Work"] as Array<String>;
    private var _labelIntensity as String = "";
    private var _labelBase as String = "";

    // --- SCREEN LAYOUT VARIABLES ---
    private var currentProfile as SessionProfile = GO_LEGS;
    private var intensityMetric as String = "";
    private var baseMetric as String = "";

    function initialize() {
        DataField.initialize();
        
        // Jednokratno učitavanje resursa pri paljenju aplikacije
        _cachedDisplayStrings[GO_LEGS]      = WatchUi.loadResource(Rez.Strings.GoLegs) as String;
        _cachedDisplayStrings[NO_FTP]       = WatchUi.loadResource(Rez.Strings.NoFtp) as String;
        _cachedDisplayStrings[THRESHOLD]    = WatchUi.loadResource(Rez.Strings.Threshold) as String;
        _cachedDisplayStrings[TEMPO_SS]     = WatchUi.loadResource(Rez.Strings.TempoSS) as String;
        _cachedDisplayStrings[AEROBIC_BASE] = WatchUi.loadResource(Rez.Strings.FatBurning) as String;
        _cachedDisplayStrings[MIXED_WORK]   = WatchUi.loadResource(Rez.Strings.MixedWork) as String;

        _labelIntensity = WatchUi.loadResource(Rez.Strings.IntensityLabel) as String;
        _labelBase      = WatchUi.loadResource(Rez.Strings.BaseLabel) as String;

        // Povlačenje naziva labele iz strings.xml
        fitField = createField(
            WatchUi.loadResource(Rez.Strings.FitLabel) as String, 
            RIDE_DIAGNOSIS_FIELD_ID, 
            FitContributor.DATA_TYPE_STRING, 
            { :count => 32, :mesgType => FitContributor.MESG_TYPE_SESSION }
        );
    }

    function compute(info as Activity.Info) as Null {
        var currentFtp = null;
        if (UserProfile has :getFunctionalThresholdPower) {
            var thresholdPower = UserProfile.getFunctionalThresholdPower(Activity.SPORT_CYCLING);
            if (thresholdPower != null && thresholdPower > 0) {
                currentFtp = thresholdPower.toFloat();
            }
        }

        if (currentFtp == null) {
            currentProfile = NO_FTP;
            intensityMetric = "";
            baseMetric = "";
            return null;
        }

        if (info != null && info.timerState == Activity.TIMER_STATE_ON && info.currentPower != null) {
            var power = info.currentPower.toFloat();
            totalSeconds++;

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
            currentProfile = GO_LEGS;
            intensityMetric = "";
            baseMetric = "";
            return null; 
        }

        var totalSecsFloat = totalSeconds.toFloat();
        var z3Pct = (z3Seconds.toFloat() / totalSecsFloat) * 100.0;
        var z4Pct = (z4Seconds.toFloat() / totalSecsFloat) * 100.0;
        var z5PlusPct = (z5PlusSeconds.toFloat() / totalSecsFloat) * 100.0;

        var highIntensityPercentage = z3Pct + z4Pct + z5PlusPct;
        var baseIntensityPercentage = 100.0 - highIntensityPercentage;

        if (z4Pct >= THRESHOLD_DURATION_MIN_PERCENTAGE || highIntensityPercentage > baseIntensityPercentage) {
            currentProfile = THRESHOLD;
        } else if (z3Pct >= TEMPO_DURATION_MIN_PERCENTAGE || z3Pct > baseIntensityPercentage) {
            currentProfile = TEMPO_SS;
        } else if (baseIntensityPercentage >= BASE_DURATION_MIN_PERCENTAGE) {
            currentProfile = AEROBIC_BASE;
        } else {
            currentProfile = MIXED_WORK;
        }
        
        var intensityValue = highIntensityPercentage.toNumber();
        intensityMetric = _labelIntensity + intensityValue + "%";
        baseMetric = _labelBase + baseIntensityPercentage.toNumber() + "%";

        if (fitField != null) {
            fitField.setData(_cachedFitStrings[currentProfile] + " - " + intensityValue + "%");
        }

        return null;
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;

        dc.setColor(getBackgroundColor(), getBackgroundColor());
        dc.clear();

        var textColor = (getBackgroundColor() == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);

        var fontToUse = Graphics.FONT_LARGE;
        var largeHeight = dc.getFontHeight(Graphics.FONT_LARGE);
        var mediumHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);

        if (height >= (largeHeight * 3)) {
            fontToUse = Graphics.FONT_LARGE;
        } else if (height >= (mediumHeight * 3)) {
            fontToUse = Graphics.FONT_MEDIUM;
        } else {
            fontToUse = Graphics.FONT_SMALL;
        }

        var displayString = _cachedDisplayStrings[currentProfile];

        if (intensityMetric.length() == 0) {
            dc.drawText(centerX, centerY, fontToUse, displayString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var lineHeight = dc.getFontHeight(fontToUse);

            dc.drawText(centerX, centerY - lineHeight, fontToUse, displayString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(centerX, centerY, fontToUse, intensityMetric, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(centerX, centerY + lineHeight, fontToUse, baseMetric, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
