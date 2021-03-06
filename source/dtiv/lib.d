module dtiv.lib;

enum
{
    FLAG_FG = 1,
    FLAG_BG = 2,
    FLAG_MODE_256 = 4,
    FLAG_NOT_USE_SKEW = 8,
    FLAG_NOOPT = 16,
    FLAG_NOT_USE_BRAILLE = 32
}

/// Get width in chars
int calcWidth(T)(in T img) pure
{
    return img.w / 4;
}

/// Get height in chars
int calcHeight(T)(in T img) pure
{
    return img.h / 8;
}

struct Pixel
{
    union
    {
        struct
        {
            ubyte r;
            ubyte g;
            ubyte b;
        };

        ubyte[3] arr;
    }

    alias arr this;
}

CharData getChar(Pixel delegate(int x, int y) getPixel, int flags, int x, int y)
{
    return flags & FLAG_NOOPT
        ? getAverageColor(getPixel, x, y, cast(ushort) 0x2584, cast(uint) 0x0000ffff)
        : getCharData(getPixel, flags, x, y);
}

struct CharData
{
    Color fgColor;
    Color bgColor;
    wchar codePoint;
}

struct Color
{
    union
    {
        struct
        {
            int r;
            int g;
            int b;
        };

        int[3] arr;
    }

    alias arr this;

    Color opOpAssign(string op, T)(in T c)
    if(op == "+")
    {
        r += c.r;
        g += c.g;
        b += c.b;

        return this;
    }

    Color opOpAssign(string op)(int f)
    if(op == "/")
    {
        r /= f;
        g /= f;
        b /= f;

        return this;
    }

    private static ubyte clamp(int e)
    {
        return cast(ubyte)( e < 0 ? 0 : (e > 255 ? 255 : e) );
    }

    private void clamp2byte()
    {
        foreach(ref e; arr)
        {
            e = clamp(e);
        }

        assert(r == toPixel.r);
        assert(g == toPixel.g);
        assert(b == toPixel.b);
    }

    Pixel toPixel() const
    {
        Pixel ret;

        foreach(ubyte i, ref e; ret)
        {
            e = cast(ubyte) arr[i];
        }

        return ret;
    }
}

private:

/// Return a CharData struct with the given code point and corresponding averag fg and bg colors.
CharData getAverageColor(Pixel delegate(int x, int y) getPixel, int x0, int y0, wchar codepoint, uint pattern)
{
    CharData ret;
    ret.codePoint = codepoint;
    uint mask = 0x8000_0000; // Most significant bit
    uint fg_count;
    uint bg_count;

    for (ubyte y = 0; y < 8; y++)
    {
        for (ubyte x = 0; x < 4; x++)
        {
            if (pattern & mask)
            {
                ret.fgColor += getPixel(x0 + x, y0 + y);
                fg_count++;
            }
            else
            {
                ret.bgColor += getPixel(x0 + x, y0 + y);
                bg_count++;
            }

            mask = mask >>> 1;
        }
    }

    // Calculate the average color value for each bucket
    if (bg_count != 0)
    {
        ret.bgColor /= bg_count;
        ret.bgColor.clamp2byte(); // fits value into 0-255
    }

    if (fg_count != 0)
    {
        ret.fgColor /= fg_count;
        ret.fgColor.clamp2byte();
    }

    return ret;
}

/// Find the best character and colors for a 4x8 part of the image at the given position
CharData getCharData(Pixel delegate(int x, int y) getPixel, int flags, int x0, int y0)
{
    Color min = {r: 255, g: 255, b: 255};
    Color max;

    // Determine the minimum and maximum value for each color channel
    for (ubyte y = 0; y < 8; y++)
        for (ubyte x = 0; x < 4; x++)
            for (ubyte i = 0; i < 3; i++)
            {
                static import cmp = std.algorithm.comparison;

                Pixel d = getPixel(x0 + x, y0 + y);
                min[i] = cmp.min(min[i], d[i]);
                max[i] = cmp.max(max[i], d[i]);
            }

    // Determine the color channel with the greatest range.
    int splitIndex = 0;
    int bestSplit = 0;
    for (ubyte i = 0; i < 3; i++)
    {
        auto diff = max[i] - min[i];

        if (diff > bestSplit)
        {
            bestSplit = diff;
            splitIndex = i;
        }
    }

    // We just split at the middle of the interval instead of computing the median.
    int splitValue = min[splitIndex] + bestSplit / 2;

    // Compute a bitmap using the given split and sum the color values for both buckets.
    uint bits = 0;

    for (ubyte y = 0; y < 8; y++)
    {
        for (ubyte x = 0; x < 4; x++)
        {
            bits = bits << 1;

            if (getPixel(x0 + x, y0 + y)[splitIndex] > splitValue)
                bits |= 1;
        }
    }

    // Find the best bitmap (box pattern) match by counting the bits
    // that don't match, including the inverted bitmaps.
    import dtiv.bitmaps;

    immutable Character[]* currPatterns =
        (flags & FLAG_NOT_USE_SKEW) ? &boxPatterns : &allBoxPatterns;

    uint best_diff = 8;
    Character bestChr = {pattern: 0x0000ffff, codePoint: 0x2584};

    foreach(ref chr; *currPatterns)
    {
        uint pattern = chr.pattern;

        for (ubyte j = 0; j < 2; j++) // twice for checking inverted pattern too
        {
            import core.bitop;

            int diff = popcnt(pattern ^ bits);

            if (diff < best_diff)
            {
                best_diff = diff;

                bestChr.codePoint = chr.codePoint;
                bestChr.pattern = chr.pattern;
            }

            pattern = ~pattern;
        }
    }

    // Braile patterns check
    if(!(flags & FLAG_NOT_USE_BRAILLE))
    {
        import dtiv.braille;

        BraillePatternAccum acc;
        acc.addPattern(bits);
        uint pattern = acc.pattern;

        for (ubyte j = 0; j < 2; j++) // twice for checking inverted pattern too
        {
            import core.bitop;

            int diff = popcnt(pattern ^ bits);

            if (diff < best_diff)
            {
                best_diff = diff;

                bestChr.codePoint = acc.codePoint;
                bestChr.pattern = pattern;
            }

            pattern = ~pattern;
        }
    }

    return getAverageColor(getPixel, x0, y0, bestChr.codePoint, bestChr.pattern);
}
