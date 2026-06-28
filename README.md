# Tuplet-Converter
MuseScore Studio plugins for converting notes to and from tuplets.

## Convert To Tuplet

Converts the selected range into a single tuplet.

## Convert From Tuplet

Converts all tuplets within the selected range into regular notes and rests. For nested tuplets, only the outermost tuplet is converted.

# Usage Notes

## Important

**This plugin modifies your score. Always save your score before using it.**

## Common

* Multiple voices and tracks can be processed simultaneously. However, processing is skipped if they do not have the same total duration or the same base note value.
* Selections spanning multiple measures are supported. However, tuplets that would cross a barline (for example, a quarter-note triplet starting on beat 4) cannot be created.
* Chord symbols are kept in place so that they do not move together with the converted notes.
* Error messages are displayed as text on the score. Remove them manually or simply use **Undo**.

## Convert To Tuplet

* The tuplet ratio is determined from the shortest note or rest within the selection. For dotted notes and rests, the value of the dot is used as the base note value.
* No conversion is performed if the selected duration cannot be represented as a tuplet.
* Rests with the same duration as the original notes remain after the generated tuplet. If desired, select the rests and press **Delete** to merge them into longer rests.

## Convert From Tuplet

* Select one or more notes or rests within a tuplet before running the plugin. Selecting only the tuplet bracket/number is currently not supported, as it may cause a crash.
* Make sure there are enough rests following the selection. Otherwise, subsequent notes may be overwritten.
* If the conversion extends beyond the final measure, additional measures are created automatically.

## Supported elements

* Nested tuplets
* Hammer-ons and pull-offs
* Slurs
* Standard bends and dives
* Playing technique symbols and text (e.g. tapping)
* Articulations
* Grace notes
* Lyrics
* Dynamics (connections to hairpins are not preserved)

## Unsupported elements (will be lost)

* Slides
* Ties
* Non-standard bends (e.g. pre-bends)
* Non-standard dives (e.g. dips)
