//===========================================================================
// Convert From Tuplet
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
//===========================================================================

import QtQuick 2.0
import MuseScore 3.0
import "TupletCommon.js" as TC

MuseScore {
    title: qsTr("Convert from Tuplet")
    description: qsTr("Remove a tuplet which includes a selection of notes and rests.")
    version: "0.2.1"
    categoryCode: "composing-arranging-tools"

    property var selection: false
    property var allTies: []
    property var allBends: []  // v0.1.6
    property var allSpans: []  // v0.1.6
    property var copiedChords: []
    property var parsedSelection: []  // v0.1.3 (trial)
    property var parsedElements: []
    property var readableElements: []
    property var globalStartTick: fraction(0, 1)
    property var globalEndTick: fraction(0, 1)
    property var globalDuration: fraction(0, 1)

    function removeTuplet() {
        var cursor = curScore.newCursor()
        cursor.rewindToFraction(globalStartTick)

        TC.removeParsedElements()

        /// Convert from Tuplet
        var t = []
        var lastTick = 0  // v0.1.7
        for (var i in readableElements) {
            var el = readableElements[i]
            cursor.track = el.track;
            console.log("CHECK---cursor in track:" + cursor.track)
            if (!t[el.track]) {
                cursor.rewindToFraction(el.startTick)
                console.log("CHECK---el.startTick:" + el.startTick.numerator + "/" + el.startTick.denominator)
                console.log("CHECK---cursor fraction " + cursor.fraction.numerator + "/" + cursor.fraction.denominator)
            } else {
                cursor.rewindToFraction(t[el.track])
                console.log("CHECK---cursor fraction " + cursor.fraction.numerator + "/" + cursor.fraction.denominator)
            }
            if (el.type == Element.TUPLET) {
                TC.addInnerTupletObj(el, cursor)
            } else {
                TC.addChordRestObj(el, cursor)
            }
            cursor.next()
            t[el.track] = cursor.fraction
            console.log("CHECK---update t of track:" + el.track + " to " + t[el.track].numerator + "/" + t[el.track].denominator)
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
            quit()  // v0.1.1
        } else {
            curScore.startCmd("Convert from tuplet")
        }
        try {
            selection = TC.readSelection()
            TC.parseSelection()
            curScore.selection.clear()  // v0.2.1 We should clear selection before removing elements
            if (readableElements.length > 0) {
                selection.endSegment = removeTuplet()  // v0.1.7
            }
            //curScore.selection.clear()
            TC.writeSelection(selection)
            curScore.endCmd()
        } catch (e) {
            // If we encounter an error, rollback all changes
            curScore.endCmd(true)
            curScore.startCmd("Convert from tuplet: " + e.toString())
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
