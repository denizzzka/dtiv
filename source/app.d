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
}

struct CharData
{
    Color fgColor;
    Color bgColor;
    ushort codePoint;
}

/// Return a CharData struct with the given code point and corresponding averag fg and bg colors.
CharData getCharData(Pixel delegate(int x, int y) getPixel, int x0, int y0, ushort codepoint, uint pattern)
{
    CharData result;
    result.codePoint = codepoint;
    uint mask = 0x80000000;
    uint fg_count;
    uint bg_count;

    for (int y = 0; y < 8; y++)
    {
        for (int x = 0; x < 4; x++)
        {
            Color avg;

            if (pattern & mask)
            {
                avg = result.fgColor;
                fg_count++;
            }
            else
            {
                avg = result.bgColor;
                bg_count++;
            }

            avg += getPixel(x0 + x, y0 + y);

            mask = mask >> 1;
        }
    }

    // Calculate the average color value for each bucket
    if (bg_count != 0)
        result.bgColor /= bg_count;

    if (fg_count != 0)
        result.fgColor /= fg_count;

    return result;
}

/// Find the best character and colors for a 4x8 part of the image at the given position
CharData getCharData(Pixel delegate(int x, int y) getPixel, int x0, int y0)
{
    Color min = {255, 255, 255};
    Color max = {0, 0, 0};

    // Determine the minimum and maximum value for each color channel
    for (int y = 0; y < 8; y++)
        for (int x = 0; x < 4; x++)
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
        if (max[i] - min[i] > bestSplit)
        {
            bestSplit = max[i] - min[i];
            splitIndex = i;
        }
    }

    // We just split at the middle of the interval instead of computing the median.
    int splitValue = min[splitIndex] + bestSplit / 2;

    // Compute a bitmap using the given split and sum the color values for both buckets.
    uint bits = 0;

    for (int y = 0; y < 8; y++)
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

    int best_diff = 8;
    Character bestChr = {pattern: 0x0000ffff, codePoint: 0x2584};

    //~ for (int i = 0; boxPatterns[i].codePoint != 0; i += 2)
    foreach(ref chr; boxPatterns)
    {
        uint pattern = chr.pattern;

        for (ubyte j = 0; j < 2; j++) // twice for checking inverted pattern too
        {
            import core.bitop;

            int diff = popcnt(chr.pattern ^ bits);

            if (diff < best_diff)
            {
                bestChr.codePoint = chr.codePoint;
                bestChr.pattern = pattern;
                best_diff = diff;
            }

            pattern = ~pattern;
        }
    }

    return getCharData(getPixel, x0, y0, bestChr.codePoint, bestChr.pattern);
}

void main()
{
    import std.stdio;
    import imageformats;

    IFImage im3 = read_image("test/lena.jpg", ColFmt.RGB);

    Pixel getPixel(IFImage img, int x, int y)
    {
        const idx = y * img.w + x;

        assert(idx >= 0);
        assert(idx < img.pixels.length);

        Pixel ret;
        ret.arr = img.pixels[idx .. idx + 3];

        return ret;
    }

    Pixel _getPixel(int x, int y)
    {
        return getPixel(im3, x, y);
    }

    auto ttt = getCharData(&_getPixel, 3, 5, 0, 0);
}
