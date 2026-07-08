import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.Activity;
import Toybox.System;
import Toybox.Application;
import Toybox.Math;

class vo2FullView extends WatchUi.View {

    private const FORMAT_TWO_DECIMALS = "%.2f";
    private const NOT_AVAILABLE = "--";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var profile = UserProfile.getProfile();
        var weightInGrams = profile.weight;
        
        // 1. ČITANJE VO2 MAX (Direktno iz profila uređaja)
        var vo2MaxVal = null as Number?;
        if (profile.vo2maxCycling != null && profile.vo2maxCycling > 0) {
            vo2MaxVal = profile.vo2maxCycling;
        } else if (profile.vo2maxRunning != null && profile.vo2maxRunning > 0) {
            vo2MaxVal = profile.vo2maxRunning;
        }

        // 2. ČITANJE PRAVOG SAKRIVENOG FTP-A SA SAT/EDGE PROFILA
        var ftpVal = null as Number?;
        if (UserProfile has :getFunctionalThresholdPower) {
            var tempFtp = UserProfile.getFunctionalThresholdPower(Activity.SPORT_CYCLING);
            if (tempFtp != null && tempFtp > 0) {
                ftpVal = tempFtp.toNumber();
            }
        }
        
        if (ftpVal == null) {
            ftpVal = 200; 
        }

        // 3. CANVAS GEOMETRY SETUP
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        
        var mySettings = System.getDeviceSettings();
        var isEdge = (mySettings.screenShape == System.SCREEN_SHAPE_RECTANGLE);
        
        if (screenWidth == 246 && screenHeight == 322) {
            isEdge = true;
        }

        var arcX = screenWidth / 2;
        var arcY = isEdge ? (screenHeight * 0.44).toNumber() : (screenHeight * 0.5).toNumber(); 
        var arcRadius = isEdge ? (screenWidth * 0.38).toNumber() : (screenWidth * 0.34).toNumber();
        var arcThickness = 12;

        var vo2String = (vo2MaxVal != null) ? vo2MaxVal.toString() : NOT_AVAILABLE; 
        var ftpString = ftpVal.toString();
        
        var wattsPerKg = 0.0;
        var wKgString = NOT_AVAILABLE;
        if (weightInGrams != null && weightInGrams > 0) {
            var weightKg = weightInGrams / 1000.0;
            wattsPerKg = ftpVal.toFloat() / weightKg;
            wKgString = wattsPerKg.format(FORMAT_TWO_DECIMALS);
        }

        // 4. DRAW GAUGE FOR W/KG
        dc.setPenWidth(arcThickness);
        var zoneColors = [
            Graphics.COLOR_RED,
            Graphics.COLOR_ORANGE,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_BLUE,
            Graphics.COLOR_PURPLE
        ] as Array<Number>;

        for (var i = 0; i < 5; i++) {
            var currentColor = zoneColors[i] as Number; 
            dc.setColor(currentColor, Graphics.COLOR_TRANSPARENT);
            var startAngle = 180 - (i * 36);
            var endAngle = startAngle - 36;
            dc.drawArc(arcX, arcY, arcRadius, Graphics.ARC_CLOCKWISE, startAngle, endAngle);
        }
        dc.setPenWidth(1); 

        // 5. DRAW NEEDLE
        if (wattsPerKg > 0) {
            var wkgPercent = (wattsPerKg - 1.2) / 3.0; 
            if (wkgPercent < 0) { wkgPercent = 0.0; }
            if (wkgPercent > 1) { wkgPercent = 1.0; }

            var needleAngleDeg = 180 - (wkgPercent * 180);
            var needleAngleRad = Math.toRadians(needleAngleDeg);

            var innerR = arcRadius - (arcThickness / 2) - 2;
            var outerR = arcRadius + (arcThickness / 2) + 4;

            var startX = (arcX + (innerR * Math.cos(needleAngleRad))).toNumber(); 
            var startY = (arcY - (innerR * Math.sin(needleAngleRad))).toNumber();
            var endX = (arcX + (outerR * Math.cos(needleAngleRad))).toNumber();
            var endY = (arcY - (outerR * Math.sin(needleAngleRad))).toNumber();

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3); 
            dc.drawLine(startX, startY, endX, endY);
            dc.setPenWidth(1); 
        }

        // 6. RENDER TEXT INSIDE THE GAUGE HUB
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        if (isEdge) {
            var wkgFont = Graphics.FONT_LARGE;
            var edgeWkgNumY = arcY - 38; 
            var edgeWkgUnitY = arcY - 12; 

            dc.drawText(arcX, edgeWkgNumY, wkgFont, wKgString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(arcX, edgeWkgUnitY, Graphics.FONT_SMALL, "W/kg", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var watchWkgNumY = arcY - 65;
            var watchWkgUnitY = arcY - 20;

            dc.drawText(arcX, watchWkgNumY, Graphics.FONT_LARGE, wKgString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(arcX, watchWkgUnitY, Graphics.FONT_XTINY, "W/kg", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // 7. RENDER DATA ROWS BELOW THE GAUGE
        var textFont = Graphics.FONT_MEDIUM;

        if (isEdge) {
            var lowerMetricsYEdge = arcY + arcRadius + 14; 
            dc.drawText(arcX, lowerMetricsYEdge, textFont, "FTP: " + ftpString + "W", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(arcX, lowerMetricsYEdge + 20, textFont, "VO2 Max: " + vo2String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var watchFont = Graphics.FONT_SMALL;
            var watchFtpY = screenHeight * 0.71; 
            var watchVo2Y = screenHeight * 0.80; 
            
            dc.drawText(arcX, watchFtpY, watchFont, "FTP: " + ftpString + "W", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(arcX, watchVo2Y, watchFont, "VO2 Max: " + vo2String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
