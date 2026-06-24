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
//===========================================================================

import QtQuick 2.0
import MuseScore 3.0
import "TupletCommon.js" as TC

MuseScore {
    title: qsTr("Convert from Tuplet")
    description: qsTr("Remove a tuplet which includes a selection of notes and rests.")
    version: "0.1.6"
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
        for (var i in readableElements) {
            var el = readableElements[i]
            console.log("CHECK---cursor to track:" + el.track)
            cursor.track = el.track;
            if (!t[el.track]) {
                console.log("CHECK---EMPTY, cursor to fraction:" + el.startTick.numerator + "/" + el.startTick.denominator)
                cursor.rewindToFraction(el.startTick)
            } else {
                console.log("CHECK---EXIST, cursor to fraction:" + t[el.track].numerator + "/" + t[el.track].denominator)
                cursor.rewindToFraction(t[el.track])
            }
            if (el.type == Element.TUPLET) {
                TC.addInnerTupletObj(el, cursor)
            } else {
                TC.addChordRestObj(el, cursor)
            }
            cursor.next()
            t[el.track] = cursor.fraction
            console.log("CHECK---update t of track:" + el.track + " to " + t[el.track].numerator + "/" + t[el.track].denominator)
        }
        //TC.addTies()
        TC.addBends()
        TC.addSpans()
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
            if (readableElements.length > 0) removeTuplet()
            curScore.selection.clear()
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
