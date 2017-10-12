module dtiv.ansi;

import dtiv.lib;
import std.stdio;

void emit_image(T)(in T image, int flags)
{
    for (int y = 0; y < image.h - 8; y += 8)
    {
        emit_row(image, flags, y);
        writeln("\x1b[0m");
    }
}

void emit_row(T)(in T image, int flags, int y)
{
    for (int x = 0; x < image.w - 4; x += 4)
    {
        CharData charData = getChar(&image.getPixel, flags, x, y);

        emit_color(flags | FLAG_BG, charData.bgColor);
        emit_color(flags | FLAG_FG, charData.fgColor);
        write(charData.codePoint);
    }
}

void emit_color(int flags, Color color)
{
    bool bg = (flags & FLAG_BG) != 0;

    if ((flags & FLAG_MODE_256) == 0)
    {
        write((bg ? "\x1b[48;2;" : "\x1b[38;2;"), color.r, ';', color.g, ';', color.b, 'm');
    }
    else
    {
        auto color_index = rgb2xterm(color) + 10;
        write(bg ? "\x1b[48;5;" : "\u001b[38;5;", color_index, "m");
    }
}

private:

auto pow2(int i)
{
    return i * i;
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

    return ret.to!int; //TODO: remove "to"
}

ubyte rgb2xterm(in Color color)
{
    with(color)
    {
        ulong smallest_distance = ulong.max;
        ulong dist;
        ubyte ret;
        ubyte i = 16;

        while(i != 0)
        {
            const tbl = colortable[i];

            dist = pow2(tbl.r - r) +
                   pow2(tbl.g - g) +
                   pow2(tbl.b - b);

            if (dist < smallest_distance)
            {
                smallest_distance = dist;
                ret = i;
            }

            i++;
        }

        return ret;
    }
}

immutable ubyte[6] COLOR_STEPS = [0, 0x5f, 0x87, 0xaf, 0xd7, 0xff];

Pixel xterm2rgb(ubyte color)
{
    Pixel rgb;

	if (color < 232)
	{
		color -= 16;
		rgb[0] = COLOR_STEPS[(color / 36) % 6];
		rgb[1] = COLOR_STEPS[(color / 6) % 6];
		rgb[2] = COLOR_STEPS[color % 6];
	}
	else
    {
        import std.conv;

		rgb[0] = rgb[1] = rgb[2] = (8 + (color - 232) * 10).to!ubyte;
    }

    return rgb;
}

static Pixel[256] colortable;

static this()
{
    assert(colortable.length >= 16);

    for (ubyte i = 16; i < colortable.length-1; i++)
        colortable[i] = xterm2rgb(i);
}
