//===========================================================================
// Tuplet Conversion Common Functions (based on new-retrograde plugin)
//
// Copyright (C) 2025 futamapapa
// Copyright (C) 2025 XiaoMigros
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 3
//  as published by the Free Software Foundation and appearing in
//  the file LICENSE
//===========================================================================
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

    var trackReadableDuration = {}

    /// Written by futamapapa
    function regularSort(a, b) {
        return a.track == b.track ? a.startTick.ticks - b.startTick.ticks : a.track - b.track;
    }

    function setReadableDuration(track, duration) {
        trackReadableDuration[track] = duration
    }

    function getReadableDuration(track) {
        if (!(track in trackReadableDuration))
            trackReadableDuration[track] = fraction(0, 1)
        return trackReadableDuration[track]
    }

    /// Written by futamapapa (came from retrogradeSelection)
    function parseSelection() {
        globalStartTick = curScore.lastMeasure.tick.plus(curScore.lastMeasure.ticks)
        readableDuration = fraction(0, 1)
        trackReadableDuration = {}
        for (var i in curScore.selection.elements) {
            var track = curScore.selection.elements[i].track
            console.log("element #" + i + "(" + curScore.selection.elements[i].userName() + ") at fraction " + curScore.selection.elements[i].fraction.numerator + "/" +  curScore.selection.elements[i].fraction.denominator + " on track" + track)
            var el = getParsedElement(curScore.selection.elements[i], parsedElements)
            if (!el) {
                continue
            } 
               
            var durationObject = el.type == Element.TUPLET ? getTupletObj(el) : getChordRestObj(el)

            parsedElements.push(el)
            readableElements.push(durationObject)

            const objEndTick = durationObject.startTick.plus(durationObject.actualDuration)
            if (objEndTick.greaterThan(globalEndTick)) {
                globalEndTick = objEndTick
            }
            if (durationObject.startTick.lessThan(globalStartTick)) {
                globalStartTick = durationObject.startTick
            }
            
            setReadableDuration(track, getReadableDuration(track).plus(durationObject.duration))  // v0.2.3 for multi track
        }
        globalDuration = globalEndTick.minus(globalStartTick)
        console.log("globalStartTick: " + globalStartTick.numerator + "/" + globalStartTick.denominator + ", globalEndTick: " + globalEndTick.numerator + "/" + globalEndTick.denominator)
        console.log("globalDuration: " + globalDuration.numerator + "/" + globalDuration.denominator)

        // v0.2.3 multi track check
        var first = null
        for (var t in trackReadableDuration) {
            var value = trackReadableDuration[t]
            if (first === null) {
                first = value
            } else if (!value.equals(first)) {
                console.log("Track-Inconsistency Error")
                return
            }
        }
        readableDuration = first
        console.log("readableDuration: " + readableDuration.numerator + "/" + readableDuration.denominator)

        // Check Consectiveness
        if (readableDuration.lessThan(globalDuration)) {
            console.log("Consectiveness Error")
            return
        }
        readableElements.sort(regularSort)
        return
    }

    /// Written by futamapapa (came from retrogradeSelection)
    // Remove existing elements (as they may not be overwritten depending on the voice situation)
    function removeParsedElements() {
        var cursor = curScore.newCursor()
        for (var i in parsedElements) {
            if (!parsedElements[i]) {
                continue
            }
            const range = [parsedElements[i].track, parsedElements[i].fraction, parsedElements[i].actualDuration]
            //removeElement(parsedElements[i])
            cursor.track = range[0]
            cursor.rewindToFraction(range[1])
            console.log("CHECK---remeving element#" + i + ": " + parsedElements[i].userName())
            removeElement(parsedElements[i])  // v0.2.0 We should not remove all elements before cursor.rewind (in voice2,3,4)
            /* v0.2.0 remove this
            if (cursor.element) {
                do {
                    removeElement(cursor.element)
                } while (cursor.next() && cursor.fraction.lessThan(range[1].plus(range[2])))
            }
            */
        }
        for (var i in parsedElements) {
            console.log("CHECK---remaining parsedElement #" + i + ": " + parsedElements[i].userName() + " in track:" + parsedElements[i].track)
        }
    }

    // Modified by futamapapa (rename from getParsedElement)
    // Find usable element (non-grace chord/rest or outermost tuplet)
    function getParsedElement(element, parsedElements) {
        var el = element
        switch (el.type) {
            case Element.NOTE:
                el = el.parent
                // fall through
            case Element.CHORD:
                el = el.noteType == NoteType.NORMAL ? el : el.parent
                // fall through
            case Element.REST:
            case Element.TUPLET:
                el = el.topTuplet ? el.topTuplet : el
                for (var i in parsedElements) {
                    if (parsedElements[i].is(el)) {
                        return false
                    }
                }
                return el

            case Element.HAMMER_ON_PULL_OFF_SEGMENT:  // v0.1.5
                getSpans(el, "hammer-on-pull-off")
                return false
            case Element.SLUR_SEGMENT:  // v0.1.6
                getSpans(el, "add-slur")
                return false
            case Element.GUITAR_BEND:  // v0.1.6
                getBends(el, "standard-bend")
                return false
            default: return false
        }
    }

    // Creates a readable object from a tuplet
    function getTupletObj(tuplet) {
        return {
            element: tuplet,  // v0.1.6
            type: tuplet.type,
            duration: tuplet.duration,
            actualDuration: tuplet.actualDuration,
            startTick: tuplet.fraction,
            track: tuplet.track,
            elements: getTupletElements(tuplet),
            ratio: fraction(tuplet.actualNotes, tuplet.normalNotes),
            bracketType: tuplet.bracketType,
            numberType: tuplet.numberType,
            visible: tuplet.visible
        }
    }

    // Modified by futamapapa
    // Returns the chords, rests and child tuplets within a tuplet
    function getTupletElements(tuplet) {
        var elementsArray = []
        for (var i in tuplet.elements) {
            if (tuplet.elements[i].type == Element.TUPLET) {
                elementsArray.push(getTupletObj(tuplet.elements[i]))
            } else {
                elementsArray.push(getChordRestObj(tuplet.elements[i]))
            }
        }
        elementsArray.sort(regularSort)
        return elementsArray
    }

    // Modified by futamapapa
    // Creates a readable object from a chord/rest
    function getChordRestObj(element) {
        getTies(element)
        return {
            element: element,  // v0.1.5
            type: element.type,
            duration: element.duration,
            actualDuration: element.actualDuration,
            startTick: element.fraction,
            track: element.track,
            notes: getNotes(element),
            annotations: getAnnotations(element),
            articulations: getArticulations(element),
            graceNotes: getGraceNotes(element),
            lyrics: getLyrics(element),  // v0.1.4
            beamMode: element.beamMode,
            offsetY: element.type == Element.REST ? element.offsetY : false,
            visible: element.type == Element.REST ? element.visible : false,
            gap: element.type == Element.REST ? element.gap : false
        }
    }

    // Creates a copy of notes used within a chord
    function getNotes(element) {
        var notes = []
        if (element.type == Element.REST) return notes
        for (var i in element.notes) {
            notes[i] = element.notes[i].clone()
        }
        return notes
    }

    // Modified by fuamapapa
    // retrieves the annotations (dynamics, tempo text, etc) of a non-grace chord/rest
    function getAnnotations(element) {
        var annoList = []
        var removeList = []
        for (var i in element.parent.annotations) {
            var el = element.parent.annotations[i]
            // if (el.track == element.track) {
            if (el.track == element.track && el.type != Element.HARMONY) {  // v0.1.2
                annoList.push(el.clone())
                removeList.push(el)
            }
        }
        for (var i in removeList) {
            removeElement(removeList[i])
        }
        return annoList
    }

    // Retrieves a chord's articulations
    function getArticulations(element) {
        var artiList = []
        if (element.type == Element.REST) return artiList
        for (var i in element.articulations) {
            artiList.push(element.articulations[i].clone())
        }
        return artiList
    }

    // Retrieves a chord's grace notes
    function getGraceNotes(element) {
        if (element.type == Element.REST || !element.graceNotes.length) {
            return []
        }
        var graceList = []
        for (var i in element.graceNotes) {
            var graceChord = element.graceNotes[0]
            graceList.push({
                duration: graceChord.duration,
                notes: getNotes(graceChord),
                type: getGraceNoteType(graceChord)
            })
            removeElement(graceChord)
        }
        return graceList
    }

    // Retrieves the type of grace note, formatted for the later add command
    // doesn't work with a switch statement
    function getGraceNoteType(graceChord) {
        var type = graceChord.notes[0].noteType
        if (type == NoteType.ACCIACCATURA)  return "acciaccatura"
        if (type == NoteType.APPOGGIATURA)  return "appoggiatura"
        if (type == NoteType.GRACE4)        return "grace4"
        if (type == NoteType.GRACE16)       return "grace16"
        if (type == NoteType.GRACE32)       return "grace32"
        if (type == NoteType.GRACE8_AFTER)  return "grace8after"
        if (type == NoteType.GRACE16_AFTER) return "grace16after"
        if (type == NoteType.GRACE32_AFTER) return "grace32after"
        return "invalid"
    }

    // Written by futamapapa v0.1.4
    function getLyrics(element) {
        var lyricList = []
        var removeList = []
        for (var i in element.lyrics) {
            var el = element.lyrics[i]
            if (el.track == element.track) {
                lyricList.push(el.clone())
                removeList.push(el)
            }
        }
        for (var i in removeList) {
            removeElement(removeList[i])
        }
        return lyricList
    }

	// Modified by futamapapa
    // Retrieves a list of notes with ties in a chordrest
    function getTies(element, cmd) {
        if (element.type == Element.REST) return
        for (var i in element.notes) {
            //if (element.notes[i].tieBack) {
            if (element.notes[i].tieForward) {  // Modified for TupletConverter
                allTies.push({
                    cmd: cmd,
                    startTick: element.fraction,
                    track: element.track,
                    note: i
                })
            }
        }
    }

    // Written by futamapapa v0.1.6
    function getBends(element, cmd) {
        var stEl = element.parent
        //var type = element.bendType
        //console.log("CHECK---get bend " + type + " from: " + stEl.userName() + " of pitch " + stEl.pitch)
        //console.log("CHECK---GuitarBendType standard-bend :" + GuitarBendType.BEND)
        //console.log("CHECK---GuitarBendType slight-bend   :" + GuitarBendType.SLIGHT_BEND)
        //if (type == GuitarBendType.BEND)            cmd = "standard-bend"
        //if (type == GuitarBendType.PRE_BEND)        cmd = "pre-bend"
        //if (type == GuitarBendType.GRACE_NOTE_BEND) cmd = "grace-note-bend"
        //if (type == GuitarBendType.SLIGHT_BEND)     cmd = "slight-bend"
        allBends.push({
            cmd: cmd,
            startElement: stEl
        })
    }

  	// Written by futamapapa
    function getSpans(element, cmd) {
        var stEl = element.spanner.startElement
        var edEl = element.spanner.endElement
        console.log("CHECK---get spanner from: " + stEl.userName() + " at fraction " + stEl.fraction.numerator + "/" + stEl.fraction.denominator)
        console.log("CHECK---get spanner   to: " + edEl.userName() + " at fraction " + edEl.fraction.numerator + "/" + edEl.fraction.denominator)
        allSpans.push({
            cmd: cmd,
            startElement: stEl,
            endElement: edEl
        })
    }

    // Modified by futamapapa
    function addChordRestObj(cr, c) {
        var t = c.fraction
        /* v0.2.0 removed this
        if (c.element) {
            // Not necessarily invalid position, could be v2
            c.setDuration(c.element.duration.numerator, c.element.duration.denominator)
            c.addRest()
            c.rewindToFraction(t)
        }
        */
        c.setDuration(cr.duration.numerator, cr.duration.denominator)
        if (cr.type == Element.REST) {
            c.addRest()
            c.rewindToFraction(t)
            // Check for full measure rest
            if (c.element.duration.equals(c.measure.timesigActual)) {
                curScore.selection.select(c.element, false)
                cmd("full-measure-rest")
            }
            c.rewindToFraction(t)
            c.element.offsetY = cr.offsetY
            c.element.visible = cr.visible
            c.element.gap = cr.gap
            parsedSelection.push(c.element)  // v0.1.3 (trial)
        } else {
            c.addNote(cr.notes[0].pitch)
            console.log("CHECK---Addes Dummy Note")
            c.rewindToFraction(t)
            var n = c.element.notes[0]
            for (var i in cr.notes) {
                // Remove trailing spanners, then add
                if (cr.notes[i].tieBack) {
                    removeElement(cr.notes[i].tieBack)
                }
                if (cr.notes[i].tieForward) {
                    removeElement(cr.notes[i].tieForward)
                }
                for (var j in cr.notes[i].spannerForward) {
                    removeElement(cr.notes[i].spannerForward[j])
                }
                for (var j in cr.notes[i].spannerBack) {
                    removeElement(cr.notes[i].spannerBack[j])
                }
                c.element.add(cr.notes[i])
                console.log("CHECK---Addes Note#" + i + " in CHORD")
                parsedSelection.push(c.element.notes[i])  // v0.1.3 (trial)
            }
            removeElement(n)
            console.log("CHECK---Removed Dummy Note")
            // If note newly crosses measure, we can't rely on duration set by cursor.
            if (!c.element.duration.equals(cr.duration)) {
                c.element.duration = cr.duration
            }
            copiedChords.push({  // v0.1.5
                old: cr.element,
                new: c.element
            })

            c.rewindToFraction(t)
            addArticulations(c, cr.articulations)
            // To do: separate front and back grace notes
            addGraceNotes(c.element.notes[0], cr.graceNotes)
        }
        c.element.beamMode = cr.beamMode
        addAnnotations(c, cr.annotations)
        addLyrics(c, cr.lyrics)  // v0.1.4
    }

	// Modified by futamapapa
    function addTupletObj(tuplet, c) {
        var t = c.fraction
        /* v0.2.0 removed this
        if (c.element) {
            // Not necessarily invalid position, could be v2
            c.setDuration(c.element.duration.numerator, c.element.duration.denominator)
            c.addRest()
            c.rewindToFraction(t)
        }
        */
        var tupletLast = t.plus(tuplet.duration);
        var measureLast = c.measure.lastSegment.fraction;
        if (tupletLast.greaterThan(measureLast)) {  // v0.1.8
            throw new Error(qsTr("Unable to add tuplet, possibly overlaps measure boundaries"))
        }
        c.addTuplet(tuplet.ratio, tuplet.duration)
        console.log("CHECK---after addTuplet--- " + c.element.userName() + " in fraction " + t.numerator + "/" + t.denominator)
        c.element.bracketType = tuplet.bracketType
        c.element.numberType = tuplet.numberType
        c.element.visible = tuplet.visible
        for (var i in tuplet.elements) {
            c.rewindToFraction(t)  // Modified for TupletConverter
            if (tuplet.elements[i].type == Element.TUPLET) {
                addTupletObj(tuplet.elements[i], c)
                console.log("CHECK---add tupletObj in fraction " + t.numerator + "/" + t.denominator)
                t = t.plus(tuplet.elements[i].duration)
            } else {
                addChordRestObj(tuplet.elements[i], c)
                console.log("CHECK---add chordRestObj in fraction " + t.numerator + "/" + t.denominator)
                c.next()
                t = c.fraction
            }
        }
    }

	// Written by futamapapa
    // Remove outer-most tuplet
    function addInnerTupletObj(tuplet, c) {
        var t = c.fraction
        console.log("CHECK---cursor fraction " + t.numerator + "/" + t.denominator)
        /* v0.2.0 remove this
        if (c.element) {
            // Not necessarily invalid position, could be v2
            c.setDuration(c.element.duration.numerator, c.element.duration.denominator)
            c.addRest()
            c.rewindToFraction(t)
        }
        */
        console.log("CHECK---lastSegment fraction = " + curScore.lastSegment.fraction.numerator + "/" + curScore.lastSegment.fraction.denominator)
        for (var i in tuplet.elements) {
            console.log("Element #" + i + " in tuplet is added to fraction " + t.numerator + "/" + t.denominator)
            if (!t.lessThan(curScore.lastSegment.fraction)) {  // v0.1.9
                console.log("CHECK---Over the last tick of score")
                cmd("append-measure")
            }
            c.rewindToFraction(t)
            console.log("CHECK---tuplet.Elements #" + i + " is type: " + tuplet.elements[i].type)
            if (tuplet.elements[i].type == Element.TUPLET) {
                addTupletObj(tuplet.elements[i], c)
            } else {
                addChordRestObj(tuplet.elements[i], c)
            }
            t = t.plus(tuplet.elements[i].duration)
        }
    }

    // Modified by futamapapa
    function addAnnotations(cursor, annotations) {
        for (var i in cursor.segment.annotations) {
            var el = cursor.segment.annotations[i]
            // if (el.track == cursor.track) {
            if (el.track == cursor.track && el.type != Element.HARMONY) {  // v0.1.2
                removeElement(el)
            }
        }
        for (var i in annotations) {
            var el = annotations[i]
            cursor.add(el)
        }
    }

    function addArticulations(cursor, artiList) {
        for (var i in artiList) {
            cursor.add(artiList[i])
        }
    }

    function addGraceNotes(note, graceList) {
        if (graceList.length == 0) {
            return
        }
        for (var i = graceList.length - 1; i >= 0; i--) {
            curScore.selection.select(note, false)
            cmd(graceList[i].type)
        }
        var graceNotes = note.parent.graceNotes
        for (var i in graceList) {
            var toRemove = graceNotes[i].notes[0]
            for (var j in graceList[i].notes) {
                graceNotes[i].add(graceList[i].notes[j])
            }
            removeElement(toRemove)
            graceNotes[i].duration = graceList[i].duration
        }
    }

    // Written by futamapapa v0.1.4
    function addLyrics(cursor, lyrics) {
        for (var i in cursor.segment.lyrics) {
            var el = cursor.segment.lyrics[i]
            if (el.track == cursor.track) {
                removeElement(el)
            }
        }
        for (var i in lyrics) {
            var el = lyrics[i]
            cursor.add(el)
        }
    }

	// Modified by futamapapa
    function addTies() {
        var c = curScore.newCursor()
        for (var i in allTies) {
            c.track = allTies[i].track
            c.rewindToFraction(allTies[i].startTick) // Since we want the end position here, don't add actualDuration
            console.log("addTies #1: cursor at fraction " + c.fraction.numerator + "/" + c.fraction.denominator)
            c.prev()
            console.log("addTies #2: cursor at fraction " + c.fraction.numerator + "/" + c.fraction.denominator)
            if (!c.element || c.element.type == Element.REST || !c.element.notes[allTies[i].note]) {
                return console.log("Unable to add tie, notes missing")
            }
            curScore.selection.select(c.element.notes[allTies[i].note], false)
            cmd(allTies[i].cmd)
        }
    }

  	// Written by futamapapa v0.1.6
    function addBends() {
        var c = curScore.newCursor()
        for (var i in allBends) {
            var stEl = allBends[i].startElement
            console.log("CHECK---bend#" + i + ": start element " + stEl.userName())

            for (var j in copiedChords) {
                for (var k in copiedChords[j].old.notes) {
                    if (stEl.is(copiedChords[j].old.notes[k])) {
                        stEl = copiedChords[j].new.notes[k]
                    }
                }
            }
            curScore.selection.select(stEl, false)
            cmd(allBends[i].cmd)
        }
    }

	// Written by futamapapa v0.1.5
    function addSpans() {
        var c = curScore.newCursor()
        for (var i in allSpans) {
            var stEl = allSpans[i].startElement
            var edEl = allSpans[i].endElement
            console.log("CHECK---span#" + i + ": start element " + stEl.userName())
            console.log("CHECK---span#" + i + ": end   element " + edEl.userName())

            for (var j in copiedChords) {
                if (stEl.is(copiedChords[j].old)) {
                    stEl = copiedChords[j].new
                }
                if (edEl.is(copiedChords[j].old)) {
                    edEl = copiedChords[j].new
                }
            }
            curScore.selection.select(stEl.notes[0], false)
            curScore.selection.select(edEl.notes[0], true)
            cmd(allSpans[i].cmd)
        }
    }

    function readSelection() {
        if (!curScore.selection.elements.length) return false
        console.log("CHECK---Number of elements in selection:" + curScore.selection.elements.length)
        if (curScore.selection.isRange) {
            return {
                isRange: true,
                startSegment: curScore.selection.startSegment.tick,
                endSegment: curScore.selection.endSegment ? curScore.selection.endSegment.tick : curScore.lastSegment.tick + 1,
                startStaff: curScore.selection.startStaff,
                endStaff: curScore.selection.endStaff
            }
        }
        var selectObj = {
            isRange: false,
            elements: []
        }
        // v0.2.1 Currently, selecting a sigle tuplet mark could occur MS Crash
        if (curScore.selection.elements.length == 1 && curScore.selection.elements[0].type == Element.TUPLET) {
            throw new Error(qsTr("A single tuplet mark cannot be selected"))
        }
        for (var i in curScore.selection.elements) {
            selectObj.elements.push(curScore.selection.elements[i])
        }
        return selectObj
    }

    function writeSelection(selectObj) {
        if (selectObj == false) return
        if (selectObj.isRange) {
            curScore.selection.selectRange(
                selectObj.startSegment,
                selectObj.endSegment,
                selectObj.startStaff,
                selectObj.endStaff
            )
            return
        }
        /* v0.1.3 temporally remove this to prohibit breaking selection
        for (var i in selectObj.elements) {
            curScore.selection.select(selectObj.elements[i], true)
        }
        */
        for (var i in parsedSelection) {  // v0.1.3 (trial)
            if (parsedSelection[i].staff) {
                curScore.selection.select(parsedSelection[i], true)
                console.log("element #" + i + "(" + curScore.selection.elements[i].userName() + ") at fraction " + curScore.selection.elements[i].fraction.numerator + "/" +  curScore.selection.elements[i].fraction.denominator + " on track" + curScore.selection.elements[i].track)
            }
        }
    }