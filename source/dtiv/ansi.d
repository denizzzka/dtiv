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
        ubyte color_index = colorToXTermPaletteIndex(color);
        write(bg ? "\x1b[48;5;" : "\u001b[38;5;", color_index, "m");
    }
}

private:

auto pow2(int i)
{
    return i * i;
}

ubyte colorToXTermPaletteIndex(Color color)
{
	if(color.r == color.g && color.g == color.b)
    {
		if(color.r == 0) return 0;
		if(color.r >= 248) return 15;

		return cast(ubyte) (232 + ((color.r - 8) / 10));
	}

	// if it isn't grey, it is color

	// the ramp goes blue, green, red, with 6 of each,
	// so just multiplying will give something good enough

	// will give something between 0 and 5, with some rounding
	auto r = (cast(int) color.r - 35) / 40;
	auto g = (cast(int) color.g - 35) / 40;
	auto b = (cast(int) color.b - 35) / 40;

	return cast(ubyte) (16 + b + g*6 + r*36);
}
