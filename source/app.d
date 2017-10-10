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

    void clamp2byte()
    {
        foreach(ref e; arr)
        {
            e = e < 0 ? 0 : (e > 255 ? 255 : e);
        }
    }
}

struct CharData
{
    Color fgColor;
    Color bgColor;
    wchar codePoint;
}

/// Return a CharData struct with the given code point and corresponding averag fg and bg colors.
CharData getCharData(Pixel delegate(int x, int y) getPixel, int x0, int y0, wchar codepoint, uint pattern)
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

    IFImage im3 = read_image("test/lena_tiny.jpg", ColFmt.RGB);

    const (Pixel) getPixel(in IFImage img, int x, int y)
    {
        const idx = y * img.w + x;

        assert(idx >= 0);
        assert(idx < img.pixels.length);

        Pixel ret;
        ret.arr = img.pixels[idx .. idx + 3];

        return ret;
    }

    int best_index(int value, in ubyte[] data)
    {
        import std.math;

        int best_diff = abs(data[0] - value);
        int result = 0;

        for (int i = 1; i < data.length; i++)
            if (abs(data[i] - value) < best_diff)
                result = i;

        return result;
    }

    import std.stdio;

    auto sqrt(int i)
    {
        import std.conv: to;
        static import std.math;

        return std.math.sqrt(i.to!float);
    }

    enum
    {
        FLAG_FG = 1,
        FLAG_BG = 2,
        FLAG_MODE_256 = 4,
        FLAG_24BIT = 8,
        FLAG_NOOPT = 16
    }

    immutable ubyte[6] COLOR_STEPS = [0, 0x5f, 0x87, 0xaf, 0xd7, 0xff];
    immutable ubyte[24] GRAYSCALE_STEPS = [
      0x08, 0x12, 0x1c, 0x26, 0x30, 0x3a, 0x44, 0x4e, 0x58, 0x62, 0x6c, 0x76,
      0x80, 0x8a, 0x94, 0x9e, 0xa8, 0xb2, 0xbc, 0xc6, 0xd0, 0xda, 0xe4, 0xee];

    void emit_color(int flags, Color color)
    {
        color.clamp2byte();

        bool bg = (flags & FLAG_BG) != 0;

        if ((flags & FLAG_MODE_256) == 0)
        {
            write((bg ? "\x1b[48;2;" : "\x1b[38;2;"), color.r, ';', color.g, ';', color.b, 'm');
            return;
        }

        int ri = best_index(color.r, COLOR_STEPS);
        int gi = best_index(color.g, COLOR_STEPS);
        int bi = best_index(color.b, COLOR_STEPS);

        int rq = COLOR_STEPS[ri];
        int gq = COLOR_STEPS[gi];
        int bq = COLOR_STEPS[bi];

        static import std.math;
        import std.conv: to;
        int gray = std.math.round(0.2989f * color.r + 0.5870f * color.g + 0.1140f * color.b).to!int;

        int gri = best_index(gray, GRAYSCALE_STEPS);
        int grq = GRAYSCALE_STEPS[gri];

        int color_index;
        if (0.3 * sqrt(rq-color.r) + 0.59 * sqrt(gq-color.g) + 0.11 * sqrt(bq-color.b) <
        0.3 * sqrt(grq-color.r) + 0.59 * sqrt(grq-color.g) + 0.11 * sqrt(grq-color.b))
        {
            color_index = 16 + 36 * ri + 6 * gi + bi;
        }
        else
        {
            color_index = 232 + gri;  // 1..24 -> 232..255
        }

        write(bg ? "\x1B[48;5;" : "\u001B[38;5;", color_index, "m");
    }

    void emit_image(in IFImage image)
    {
        const int flags = 0;

        Pixel _getPixel(int x, int y)
        {
            return getPixel(image, x, y);
        }

        for (int y = 0; y < image.h - 8; y += 8)
        {
            for (int x = 0; x < image.w - 4; x += 4)
            {
                CharData charData = flags & FLAG_NOOPT
                    ? getCharData(&_getPixel, x, y, cast(ushort) 0x2584, cast(uint) 0x0000ffff)
                    : getCharData(&_getPixel, x, y);

                emit_color(flags | FLAG_BG, charData.bgColor);
                emit_color(flags | FLAG_FG, charData.fgColor);
                std.stdio.write(charData.codePoint);
            }

            writeln("\x1b[0m");
        }
    }

    emit_image(im3);
}
