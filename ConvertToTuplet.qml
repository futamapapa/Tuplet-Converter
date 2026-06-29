//===========================================================================
// Convert To Tuplet
//
// Copyright (C) 2025 futamapapa
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 3
//  as published by the Free Software Foundation and appearing in
//  the file LICENSE.
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
//  v0.2.4: Preserve the current selection if the operation cannot be performed
//  v0.2.5: Clean up license headers
//  v0.2.6: Skip processing instead of reporting an error for crossing barlines
//  v0.2.7: Refactor to improve readability
//===========================================================================

import QtQuick 2.0
import MuseScore 3.0
import "TupletCommon.js" as TC

MuseScore {
    title: qsTr("Convert to Tuplet")
    description: qsTr("Add a tuplet to a selection of notes and rests.")
    version: "0.2.7"
    categoryCode: "composing-arranging-tools"

    property var parsedSelection: []  // v0.1.3 (trial)
    property var parsedElements: []
    property var readableElements: []

    function addTuplet(parsedTime) {
        const cursor = curScore.newCursor()
        cursor.rewindToFraction(parsedTime.globalStartTick)

        let tupletRatioN = parsedTime.globalDuration.numerator
        let tupletRatioD = Math.pow(2, Math.floor(Math.log2(tupletRatioN)))
        let tupletDurationN = 1
        let tupletDurationD = parsedTime.globalDuration.denominator / tupletRatioD
        // v0.2.2 Algorithm fixed 
        if (parsedTime.readableDuration.equals(fraction(0,1))) {
            console.log("readableDuration is unavailable.")
            return false
        } 
        while (tupletRatioD < parsedTime.readableDuration.denominator) {
            tupletRatioN *= 2
            tupletRatioD *= 2
        }
        while (tupletRatioN >= 2 * parsedTime.readableDuration.numerator) {
            tupletRatioN /= 2
            tupletRatioD /= 2    
        }
        const timeSigD = cursor.measure.timesigNominal.denominator
        if (timeSigD == 8) {
            tupletRatioD = 3 * Math.max(Math.floor(tupletRatioN / 3), 1)
            tupletDurationN *= 3
            tupletDurationD *= 4
        }
        const tupletRatio = fraction(tupletRatioN, tupletRatioD)
        const tupletDuration = fraction(tupletDurationN, tupletDurationD)

        console.log("Candidate Tuplet of Ratio " + tupletRatio.numerator + "/" + tupletRatio.denominator + " in Duration " + tupletDuration.numerator + "/" + tupletDuration.denominator)

        /// Tuplet Rules
        if (tupletRatioN == 1 && Math.log2(tupletRatioD) == Math.floor(Math.log2(tupletRatioD))) {
            console.log("Tuplet Rule Violation #1: replacable to normal duration")
            return false
        } else if (Math.log2(tupletRatioN) == Math.floor(Math.log2(tupletRatioN)) && timeSigD != 8) {
            console.log("Tuplet Rule Violation #2: duplet in non-complex time signature")
            return false
        }

        // v0.2.6 moved to here
        const tupletLast = parsedTime.globalStartTick.plus(tupletDuration);
        const measureLast = cursor.measure.lastSegment.fraction;
        if (tupletLast.greaterThan(measureLast)) {  // v0.1.8
            //throw new Error(qsTr("Unable to add tuplet, possibly overlaps measure boundaries"))
            console.log("Unable to add tuplet, possibly overlaps measure boundaries")
            return false
        }

        curScore.selection.clear()  // v0.2.1 We should clear selection before removing elements  // v0.2.4 moved to here
        TC.removeParsedElements()

        /// Convert to Tuplet
        const t = []
        let lastTick = 0  // v0.1.7
        for (let i in readableElements) {
            const el = readableElements[i]
            console.log("CHECK---cursor to track:" + el.track)
            cursor.track = el.track;
            if (!t[el.track]) {
                cursor.rewindToFraction(parsedTime.globalStartTick)
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
        }
        let parsedTime = null
        try {
            const selection = TC.readSelection()
            if (selection) {
                parsedTime = TC.parseSelection()
                if (parsedTime.ok && readableElements.length > 0) {
                    curScore.startCmd("Convert to tuplet")  // v0.2.4 moved to here
                    selection.endSegment = addTuplet(parsedTime)  // v0.1.7
                    if (selection.endSegment) {
                        TC.writeSelection(selection)
                    }   
                    curScore.endCmd()  // v0.2.4 moved to here
                }
            }
        } catch (e) {
            // If we encounter an error, rollback all changes
            curScore.endCmd(true)
            curScore.startCmd("Convert to tuplet: " + e.toString())
            const text = newElement(Element.STAFF_TEXT)
            text.text = e.toString()
            const c = curScore.newCursor()
            c.track = 0
            c.rewindToFraction(parsedTime? parsedTime.globalStartTick : fraction(0, 1))
            c.add(text)
            curScore.endCmd()
        }
        quit()
    }
}
