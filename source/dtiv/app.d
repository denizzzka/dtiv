module dtiv.main;

import dtiv.lib;

void main(string[] args)
{
    import dtiv.ansi;
    import std.getopt;

    bool noBlocks;
    bool colors256;
    bool disableShapes;
    bool disableBraille;

    auto opts = getopt(
        args,
        "noblocks|0", "No block character adjustment, always use top half block char.", &noBlocks,
        "256", "Use 256 color mode.", &colors256,
        "noshapes", "Disable usage of triangle shapes.", &disableShapes,
        "nobraille", "Disable usage of triangle shapes.", &disableBraille,
    );

    if(opts.helpWanted)
    {
        defaultGetoptPrinter("Options:", opts.options);
        return;
    }

    int flags;

    if(noBlocks) flags |= FLAG_NOOPT;
    if(colors256) flags |= FLAG_MODE_256;
    if(disableShapes) flags |= FLAG_NOT_USE_SKEW;
    if(disableBraille) flags |= FLAG_NOT_USE_BRAILLE;

    auto img = IFImgWrapper(args[$-1]);

    emit_image(img, flags);
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

    Pixel getPixel(int x, int y) const
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

/// Represents raw bytes picture
/// Useful for testing purposes
struct RawImgWrapper
{
    int w = 32;
    int h = 32;
    private ubyte[] pixels;

    this(string filename)
    {
        import std.file;
        pixels = cast(ubyte[]) read(filename);
    }

    Pixel getPixel(int x, int y) const
    {
        assert (x >= 0);
        assert (y >= 0);

        const idx = (y * w + x) * Pixel.arr.length;

        assert(idx >= 0);
        assert(idx < pixels.length);

        Pixel ret;
        ret.arr = pixels[idx .. idx + Pixel.arr.length];

        return ret;
    }
}
