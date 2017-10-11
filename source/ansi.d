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
    color.clamp2byte();

    bool bg = (flags & FLAG_BG) != 0;

    if ((flags & FLAG_MODE_256) == 0)
    {
        write((bg ? "\x1b[48;2;" : "\x1b[38;2;"), color.r, ';', color.g, ';', color.b, 'm');
        return;
    }
    else
    {
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
}

private:

auto pow2(int i)
{
    return i * i;
}

immutable ubyte[6] COLOR_STEPS = [0, 0x5f, 0x87, 0xaf, 0xd7, 0xff];
immutable ubyte[24] GRAYSCALE_STEPS =
[
  0x08, 0x12, 0x1c, 0x26, 0x30, 0x3a, 0x44, 0x4e, 0x58, 0x62, 0x6c, 0x76,
  0x80, 0x8a, 0x94, 0x9e, 0xa8, 0xb2, 0xbc, 0xc6, 0xd0, 0xda, 0xe4, 0xee
];
