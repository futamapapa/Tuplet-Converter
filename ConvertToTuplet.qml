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
//===========================================================================

import QtQuick 2.0
import MuseScore 3.0
import "TupletCommon.js" as TC

MuseScore {
    title: qsTr("Convert to Tuplet")
    description: qsTr("Add a tuplet to a selection of notes and rests.")
    version: "0.1.5"
    categoryCode: "composing-arranging-tools"

    property var selection: false
    property var allTies: []
    property var allHopos: []
    property var copiedChords: []
    property var parsedSelection: []  // v0.1.3 (trial)
    property var parsedElements: []
    property var readableElements: []
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
        while (tupletRatioN >= 2 * readableElements.length) {
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
        var t = [];
        for (var i in readableElements) {
            var el = readableElements[i]
            console.log("CHECK---cursor to track:" + el.track)
            cursor.track = el.track;
            if (!t[el.track]) {
                console.log("CHECK---EMPTY, cursor to fraction:" + el.startTick.numerator + "/" + el.startTick.denominator)
                cursor.rewindToFraction(el.startTick)
                cursor.addTuplet(tupletRatio, tupletDuration)
                console.log("Add Tuplet of Ratio " + tupletRatio.numerator + "/" + tupletRatio.denominator + " in Duration " + tupletDuration.numerator + "/" + tupletDuration.denominator)
            } else {
                console.log("CHECK---EXIST, cursor to fraction:" + t[el.track].numerator + "/" + t[el.track].denominator)
                cursor.rewindToFraction(t[el.track])
            }
            if (el.type == Element.TUPLET) {
                TC.addTupletObj(el, cursor)
            } else {
                TC.addChordRestObj(el, cursor)
            }
            cursor.next()
            t[el.track] = cursor.fraction
            console.log("CHECK---update t of track:" + el.track + " to " + t[el.track].numerator + "/" + t[el.track].denominator)
        }
        //TC.addTies(allTies)
        TC.addSpans(allHopos, "hammer-on-pull-off")
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
            if (readableElements.length > 0) addTuplet()
            curScore.selection.clear()
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
