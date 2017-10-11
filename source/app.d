module dtiv.main;

import dtiv.lib;

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

void main(string[] args)
{
    import dtiv.ansi;
    import std.stdio;

    auto im3 = IFImgWrapper(args[1]);
    //~ auto im3 = RawImgWrapper(args[1]);

    emit_image(im3);
}
