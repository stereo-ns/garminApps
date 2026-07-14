import Toybox.Activity;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.FitContributor;

class rideEffectView extends WatchUi.SimpleDataField {

    // --- PHYSIOLOGICAL DIAGNOSIS DISTRIBUTION THRESHOLDS (%) ---
    private const THRESHOLD_DURATION_MIN_PERCENTAGE = 20.0;  // Minimum 20% in Z4 triggers Threshold
    private const TEMPO_DURATION_MIN_PERCENTAGE = 35.0;      // Minimum 35% in Z3 triggers Tempo
    private const BASE_DURATION_MIN_PERCENTAGE = 50.0;       // Minimum 50% in Z2 triggers Base
    private const ANAEROBIC_FLATLINE_LIMIT_PERCENTAGE = 5.0;  // Below 5% in Z5+ appends a minus sign

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

    function initialize() {
        SimpleDataField.initialize();
        label = "Ride Effect";
        
        // MESG_TYPE_SESSION registers this as a summary metric at the end of the activity
        fitField = createField(
            "Session Profile", 
            RIDE_DIAGNOSIS_FIELD_ID, 
            FitContributor.DATA_TYPE_STRING, 
            { :count => 32, :mesgType => FitContributor.MESG_TYPE_SESSION }
        );
    }

    // Silent background execution loop for data collection
    function compute(info as Activity.Info) {
        // Initialize limits at 0.0 - strictly no hardcoded guessing or default constants
        var z1Max = 0.0;
        var z2Max = 0.0;
        var z3Max = 0.0;
        var z4Max = 0.0;

        // Fetch native cycling power zones array straight from Edge 840 hardware settings
        var rawZones = UserProfile.getPowerZones(Activity.SPORT_CYCLING) as Lang.Array or Null;
        
        if (rawZones != null && rawZones.size() >= 5) {
            z1Max = rawZones[0].toFloat(); // Zone 1 upper limit (Watts)
            z2Max = rawZones[1].toFloat(); // Zone 2 upper limit (Watts)
            z3Max = rawZones[2].toFloat(); // Zone 3 upper limit (Watts)
            z4Max = rawZones[3].toFloat(); // Zone 4 upper limit (Watts)
        }

        // Severe system fault alert: If hardware profile retrieval fails, abort tracking immediately
        if (z4Max <= 0.0) {
            return "No Profile Found";
        }

        // Real-time power sensor processing channel
        if (info != null && info.currentPower != null) {
            var power = info.currentPower.toFloat();
            totalSeconds++;

            // Sort incoming power stream sample metrics based purely on physical device layout
            if (power <= z1Max) { z1Seconds++; }
            else if (power <= z2Max) { z2Seconds++; }
            else if (power <= z3Max) { z3Seconds++; }
            else if (power <= z4Max) { z4Seconds++; }
            else { z5PlusSeconds++; }
        }

        // Dynamically update the developer field record in the background FIT stream
        if (totalSeconds > 0 && fitField != null) {
            fitField.setData(calculateSessionProfile());
        }

        return "Okej";
    }

    // Determine the metabolic outcome using hierarchical system dominance
    private function calculateSessionProfile() as String {
        if (totalSeconds == 0) { return "No Data"; }

        var totalSecsFloat = totalSeconds.toFloat();
        var z3Percentage = (z3Seconds.toFloat() / totalSecsFloat) * 100.0;
        var z4Percentage = (z4Seconds.toFloat() / totalSecsFloat) * 100.0;
        var z5PlusPercentage = (z5PlusSeconds.toFloat() / totalSecsFloat) * 100.0;

        var highIntensityPercentage = z3Percentage + z4Percentage + z5PlusPercentage;
        var baseIntensityPercentage = 100.0 - highIntensityPercentage;

        // 1. THRESHOLD SYSTEM DOMINANCE
        if (z4Percentage >= THRESHOLD_DURATION_MIN_PERCENTAGE || highIntensityPercentage > baseIntensityPercentage) {
            if (z5PlusPercentage < ANAEROBIC_FLATLINE_LIMIT_PERCENTAGE) {
                return "Threshold -";
            }
            return "Threshold";
        }

        // 2. TEMPO / SWEET SPOT SYSTEM DOMINANCE
        if (z3Percentage >= TEMPO_DURATION_MIN_PERCENTAGE || z3Percentage > baseIntensityPercentage) {
            return "Tempo / S.Spot";
        }

        // 3. AEROBIC BASE SYSTEM DOMINANCE
        if (baseIntensityPercentage >= BASE_DURATION_MIN_PERCENTAGE) {
            return "Aerobic Base";
        }

        // 4. MIXED INFRASTRUCTURE WORKLOAD
        return "Mixed Work";
    }
}
