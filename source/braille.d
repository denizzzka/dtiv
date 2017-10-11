module dtiv.braille;

package:

/*
 * Dots:
 *
 *   ,___,
 *   |1 4|
 *   |2 5|
 *   |3 6|
 *   |7 8|
 *   `````
 *
 * Hex representation:
 *
 *   [0x01, 0x08]
 *   [0x02, 0x10]
 *   [0x04, 0x20]
 *   [0x40, 0x80]
 */

struct Dot
{
    uint pattern;
    ubyte symbol;
}

immutable Dot[] dots =
[
    {0xc000_0000, 0x01}, // top left dot
    {0x00c0_0000, 0x02},
    {0x0000_c000, 0x04},
    {0x0000_00c0, 0x40}, // closest to bottom left dot
    {0x3000_0000, 0x08}, // top right dot
    {0x0030_0000, 0x10},
    {0x0000_3000, 0x20},
    {0x0000_0030, 0x80}, // closest to bottom right dot
];

struct BraillePatternAccum
{
    private uint _pattern;
    private ubyte currChar;

    void addPattern(uint pattern)
    {
        foreach(d; dots)
        {
            if(pattern & d.pattern)
            {
                currChar |= d.symbol;
                _pattern |= d.pattern;
            }
        }
    }

    wchar codePoint() const
    {
        enum wchar brailleOffset = 0x2800;

        return brailleOffset + currChar;
    }

    uint pattern() const
    {
        return _pattern;
    }
}
