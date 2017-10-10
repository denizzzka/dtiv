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

struct IFImgWrapper
{
    import imageformats;

    IFImage img;
    alias img this;

    this(string filename)
    {
        img = read_image(filename, ColFmt.RGB);
    }

    Pixel getPixel(int x, int y)
    {
        assert (x >= 0);
        assert (y >= 0);

        const idx = (y * img.w + x) * Pixel.arr.length;

        assert(idx >= 0);
        assert(idx < img.pixels.length);

        Pixel ret;
        ret.arr = img.pixels[idx .. idx + Pixel.arr.length];

        return ret;
    }
}

struct CharData
{
    Color fgColor;
    Color bgColor;
    wchar codePoint;
}

/// Return a CharData struct with the given code point and corresponding averag fg and bg colors.
CharData getAverageColor(Pixel delegate(int x, int y) getPixel, int x0, int y0, wchar codepoint, uint pattern)
{
    CharData ret;
    ret.codePoint = codepoint;
    uint mask = 0x8000_0000; // Most significant bit
    uint fg_count;
    uint bg_count;

    for (int y = 0; y < 8; y++)
    {
        for (int x = 0; x < 4; x++)
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

            mask = mask >> 1;
        }
    }

    // Calculate the average color value for each bucket
    if (bg_count != 0)
        ret.bgColor /= bg_count;

    if (fg_count != 0)
        ret.fgColor /= fg_count;

    return ret;
}

/// Find the best character and colors for a 4x8 part of the image at the given position
CharData getCharData(Pixel delegate(int x, int y) getPixel, bool useSkew, int x0, int y0)
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

    immutable Character[]* currPatterns =
        useSkew ? &allBoxPatterns : &boxPatterns;

    int best_diff = 8;
    Character bestChr = {pattern: 0x0000ffff, codePoint: 0x2584};

    foreach(ref chr; *currPatterns)
    {
        uint pattern = chr.pattern;

        for (ubyte j = 0; j < 2; j++) // twice for checking inverted pattern too
        {
            import core.bitop;

            int diff = popcnt(chr.pattern ^ bits);

            if (diff < best_diff)
            {
                best_diff = diff;

                bestChr.codePoint = chr.codePoint;
                bestChr.pattern = pattern;
            }

            pattern = ~pattern;
        }
    }

    return getAverageColor(getPixel, x0, y0, bestChr.codePoint, bestChr.pattern);
}

void main(string[] args)
{
    import std.stdio;

    auto im3 = IFImgWrapper(args[1]);

    const (Pixel) getPixel(T)(in T img, int x, int y)
    {
        assert (x >= 0);
        assert (y >= 0);

        const idx = (y * img.w + x) * Pixel.arr.length;

        assert(idx >= 0);
        assert(idx < img.pixels.length);

        Pixel ret;
        ret.arr = img.pixels[idx .. idx + Pixel.arr.length];

        return ret;
    }

    int best_index(int value, in ubyte[] data)
    {
        int best_diff = int.max;
        size_t ret;

        foreach(i, d; data)
        {
            import std.math: abs;

            int tmp = abs(value - data[0]);

            if(tmp < best_diff)
            {
                ret = i;
                best_diff = tmp;
            }
        }

        import std.conv: to;

        return ret.to!int;
    }

    import std.stdio;

    auto pow2(int i)
    {
        return i * i;
    }

    enum
    {
        FLAG_FG = 1,
        FLAG_BG = 2,
        FLAG_MODE_256 = 4,
        //~ FLAG_24BIT = 8,
        FLAG_NOT_USE_SKEW = 8,
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
        //~ int gray = std.math.round(0.2989f * color.r + 0.5870f * color.g + 0.1140f * color.b).to!int;
        int gray = std.math.round(color.r * 0.2989f + color.g * 0.5870f + color.b * 0.1140f).to!int;

        int gri = best_index(gray, GRAYSCALE_STEPS);
        int grq = GRAYSCALE_STEPS[gri];

        int color_index;
        if (0.3 * pow2(rq-color.r) + 0.59 * pow2(gq-color.g) + 0.11 * pow2(bq-color.b) <
        0.3 * pow2(grq-color.r) + 0.59 * pow2(grq-color.g) + 0.11 * pow2(grq-color.b))
        {
            color_index = 16 + 36 * ri + 6 * gi + bi;
        }
        else
        {
            color_index = 232 + gri;  // 1..24 -> 232..255
        }

        write(bg ? "\x1B[48;5;" : "\u001B[38;5;", color_index, "m");
    }

    void emit_image(T)(in T image)
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
                    ? getAverageColor(&_getPixel, x, y, cast(ushort) 0x2584, cast(uint) 0x0000ffff)
                    : getCharData(&_getPixel, !(flags & FLAG_NOT_USE_SKEW), x, y);

                emit_color(flags | FLAG_BG, charData.bgColor);
                emit_color(flags | FLAG_FG, charData.fgColor);
                std.stdio.write(charData.codePoint);
                //~ emitCodepoint(charData.codePoint);
            }

            writeln("\x1b[0m");
        }
    }

    emit_image(im3);
}

void emitCodepoint(wchar codepoint)
{
    import std.stdio: wr = write;

    void write(T)(T cpoint) @property
    {
        wr(cast(char) cpoint);
    }

  if (codepoint < 128) {
    codepoint.wr;
  } else if (codepoint < 0x7ff) {
    write(0xc0 | (codepoint >> 6));
    write(0x80 | (codepoint & 0x3f));
  } else if (codepoint < 0xffff) {
    write(0xe0 | (codepoint >> 12));
    write(0x80 | ((codepoint >> 6) & 0x3f));
    write(0x80 | (codepoint & 0x3f));
  } else if (codepoint < 0x10ffff) {
    write(0xf0 | (codepoint >> 18));
    write(0x80 | ((codepoint >> 12) & 0x3f));
    write(0x80 | ((codepoint >> 6) & 0x3f));
    write(0x80 | (codepoint & 0x3f));
  } else {
    "ERROR".wr;
  }
}
