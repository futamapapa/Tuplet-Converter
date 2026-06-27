//===========================================================================
// Convert To Tuplet
//
// Copyright (C) 2025 futamapapa
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 3
//  as published by the Free Software Foundation and appearing in
//  the file LICENSE
//===========================================================================
//  v0.1.1: Fix running without selection
//  v0.1.2: Prohibit moving CHORD SYMBOL (Element.HARMONY)
//  v0.1.3: Prohibit braking selection after run with non-range selection
//  v0.1.4: Add lyrics handler
//  v0.1.5: Add hammer-on-pull-off handler
//  v0.1.6: Add slur & standard-bend handler
//  v0.1.7: selection modifier after run
//  v0.1.8: Tweak error detection of overlapping measure boundaries
//  v0.1.9: Add append-measure when over the last measure
//  v0.2.0: Fix removing objects in voice2,3,4
//  v0.2.1: Avoid crash when a single tuplet mark is selected
//  v0.2.2: Fix the algorithm for determining tuplet ratio with mixed note values
//  v0.2.3: Fix actual duration calculation when processing multiple tracks
//===========================================================================

import QtQuick 2.0
import MuseScore 3.0
import "TupletCommon.js" as TC

MuseScore {
    title: qsTr("Convert to Tuplet")
    description: qsTr("Add a tuplet to a selection of notes and rests.")
    version: "0.2.1"
    categoryCode: "composing-arranging-tools"

    property var selection: false
    property var allTies: []
    property var allBends: []
    property var allSpans: []
    property var copiedChords: []
    property var parsedSelection: []  // v0.1.3 (trial)
    property var parsedElements: []
    property var readableElements: []
    property var readableDuration: fraction(0, 1)
    property var globalStartTick: fraction(0, 1)
    property var globalEndTick: fraction(0, 1)
    property var globalDuration: fraction(0, 1)

    function addTuplet() {
        var cursor = curScore.newCursor()
        cursor.rewindToFraction(globalStartTick)

        var tupletRatioN = globalDuration.numerator
        var tupletRatioD = Math.pow(2, Math.floor(Math.log2(tupletRatioN)))
        var tupletDurationN = 1
        var tupletDurationD = globalDuration.denominator / tupletRatioD
        // v0.2.2 Algorithm fixed 
        if (readableDuration.equals(fraction(0,1))) {
            console.log("readableDuration is unavailable.")
            return
        } 
        while (tupletRatioD < readableDuration.denominator) {
            tupletRatioN *= 2
            tupletRatioD *= 2
        }
        while (tupletRatioN >= 2 * readableDuration.numerator) {
            tupletRatioN /= 2
            tupletRatioD /= 2    
        }
        var timeSigD = cursor.measure.timesigNominal.denominator
        if (timeSigD == 8) {
            tupletRatioD = 3 * Math.max(Math.floor(tupletRatioN / 3), 1)
            tupletDurationN *= 3
            tupletDurationD *= 4
        }
        var tupletRatio = fraction(tupletRatioN, tupletRatioD)
        var tupletDuration = fraction(tupletDurationN, tupletDurationD)

        console.log("Candidate Tuplet of Ratio " + tupletRatio.numerator + "/" + tupletRatio.denominator + " in Duration " + tupletDuration.numerator + "/" + tupletDuration.denominator)

        /// Tuplet Rules
        if (tupletRatioN == 1 && Math.log2(tupletRatioD) == Math.floor(Math.log2(tupletRatioD))) {
            console.log("Tuplet Rule Violation #1: replacable to normal duration")
            return
        } else if (Math.log2(tupletRatioN) == Math.floor(Math.log2(tupletRatioN)) && timeSigD != 8) {
            console.log("Tuplet Rule Violation #2: duplet in non-complex time signature")
            return
        }

        TC.removeParsedElements()

        /// Convert to Tuplet
        var t = []
        var lastTick = 0  // v0.1.7
        for (var i in readableElements) {
            var el = readableElements[i]
            console.log("CHECK---cursor to track:" + el.track)
            cursor.track = el.track;
            if (!t[el.track]) {
                cursor.rewindToFraction(globalStartTick)
                var tupletLast = globalStartTick.plus(tupletDuration);
                var measureLast = cursor.measure.lastSegment.fraction;
                if (tupletLast.greaterThan(measureLast)) {  // v0.1.8
                    throw new Error(qsTr("Unable to add tuplet, possibly overlaps measure boundaries"))
                }
                cursor.addTuplet(tupletRatio, tupletDuration)
                console.log("Track#" + el.track + ": Add Tuplet of Ratio " + tupletRatio.numerator + "/" + tupletRatio.denominator + " in Duration " + tupletDuration.numerator + "/" + tupletDuration.denominator + " at tick " + cursor.tick)
            } else {
                cursor.rewindToFraction(t[el.track])
            }

            if (el.type == Element.TUPLET) {
                TC.addTupletObj(el, cursor)
            } else {
                TC.addChordRestObj(el, cursor)
            }
            cursor.next()
            t[el.track] = cursor.fraction
            if (cursor.tick > lastTick) {  // v0.1.7
                lastTick = cursor.tick
            }
        }
        //TC.addTies()
        TC.addBends()
        TC.addSpans()
        return lastTick
    }

    onRun: {
        if (!curScore.selection.elements.length) {
            quit()  // v.0.1.1
        } else {
            curScore.startCmd("Convert to tuplet")
        }
        try {
            selection = TC.readSelection()
            TC.parseSelection()
            curScore.selection.clear()  // v0.2.1 We should clear selection before removing elements
            if (readableElements.length > 0) {
                selection.endSegment = addTuplet()  // v0.1.7
            }
            //curScore.selection.clear()
            TC.writeSelection(selection)
            curScore.endCmd()
        } catch (e) {
            // If we encounter an error, rollback all changes
            curScore.endCmd(true)
            curScore.startCmd("Convert to tuplet: " + e.toString())
            var text = newElement(Element.STAFF_TEXT)
            text.text = e.toString()
            var c = curScore.newCursor()
            c.track = 0
            c.rewindToFraction(globalStartTick)
            c.add(text)
            curScore.endCmd()
        }
        quit()
    }
}
