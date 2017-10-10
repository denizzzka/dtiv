import dtiv.bitmaps;

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
}

struct Color
{
    int r;
    int g;
    int b;

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

// Return a CharData struct with the given code point and corresponding averag fg and bg colors.
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
