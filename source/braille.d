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

struct brailleAccum
{
    private ubyte currChar;

    void addPattern(uint pattern)
    {
        if(pattern & 0x4000_0000) // top left dot
            currChar |= 0x01;

        if(pattern & 0x0040_0000)
            currChar |= 0x02;

        if(pattern & 0x0000_4000)
            currChar |= 0x04;

        if(pattern & 0x0000_0040) // closest to bottom left dot
            currChar |= 0x40;

        if(pattern & 0x1000_0000) // top right dot
            currChar |= 0x08;

        if(pattern & 0x0010_0000)
            currChar |= 0x10;

        if(pattern & 0x0000_1000)
            currChar |= 0x20;

        if(pattern & 0x0000_0010) // closest to bottom right dot
            currChar |= 0x80;
    }

    wchar getCodepoint() const
    {
        enum wchar brailleOffset = 0x2800;

        return brailleOffset + currChar;
    }
}
