public class Program {
    private static int Paint(int x, int y, int width, int height, int rgb) {
        if (width < 1 || height < 1 || width > 2048 || height > 2048) { return -22; }
        int rows = 65536 / width;
        if (rows < 1) { return -22; }
        int drawn = 0;
        while (drawn < height) {
            int count = height - drawn;
            if (count > rows) { count = rows; }
            int result = System.Australis.Display.FillRect(x, y + drawn,
                width, count, rgb);
            if (result != 0) { return result; }
            drawn = drawn + count;
        }
        return 0;
    }

    // Each compositor-owned layout stores x, y, width, height, visibility,
    // maximization, restore geometry, and the hovered control. Clients never
    // supply these fields.
    private static int Read16(byte[] data, int offset) {
        return data[offset] + data[offset + 1] * 256;
    }
    private static void Write16(byte[] data, int offset, int value) {
        data[offset] = (byte)(value % 256);
        data[offset + 1] = (byte)(value / 256);
    }
    private static void InitLayout(byte[] layout, int x, int y,
        int width, int height) {
        Write16(layout, 0, x); Write16(layout, 2, y);
        Write16(layout, 4, width); Write16(layout, 6, height);
        layout[8] = 1; layout[9] = 0; layout[18] = 0;
    }
    private static bool Visible(byte[] state, byte[] layout) {
        return state[1] == 1 && layout[8] == 1;
    }
    private static int ContentTop(byte[] layout) {
        int top = Read16(layout, 2) + 36;
        if (layout[9] == 1) { top = Read16(layout, 2) + 8; }
        return top;
    }
    private static void CopyLayout(byte[] source, byte[] target) {
        int i = 0;
        while (i < 19) { target[i] = source[i]; i = i + 1; }
    }
    private static bool LayoutChanged(byte[] before, byte[] after) {
        int i = 0;
        while (i < 18) {
            if (before[i] != after[i]) { return true; }
            i = i + 1;
        }
        return false;
    }
    private static void ToggleMax(byte[] layout, int width, int height) {
        if (layout[9] == 0) {
            Write16(layout, 10, Read16(layout, 0));
            Write16(layout, 12, Read16(layout, 2));
            Write16(layout, 14, Read16(layout, 4));
            Write16(layout, 16, Read16(layout, 6));
            Write16(layout, 0, 0); Write16(layout, 2, 32);
            Write16(layout, 4, width); Write16(layout, 6, height - 32);
            layout[9] = 1;
        } else {
            Write16(layout, 0, Read16(layout, 10));
            Write16(layout, 2, Read16(layout, 12));
            Write16(layout, 4, Read16(layout, 14));
            Write16(layout, 6, Read16(layout, 16));
            layout[9] = 0;
        }
        layout[18] = 0;
    }

    // The clip also restores the small rectangle under the old cursor.
    private static void SetClip(byte[] clip, int x, int y, int width, int height) {
        clip[0] = (byte)(x % 256); clip[1] = (byte)(x / 256);
        clip[2] = (byte)(y % 256); clip[3] = (byte)(y / 256);
        clip[4] = (byte)(width % 256); clip[5] = (byte)(width / 256);
        clip[6] = (byte)(height % 256); clip[7] = (byte)(height / 256);
    }
    private static int Clip(int x, int y, int width, int height, int rgb,
        byte[] clip) {
        int clipX = clip[0] + clip[1] * 256;
        int clipY = clip[2] + clip[3] * 256;
        int clipWidth = clip[4] + clip[5] * 256;
        int clipHeight = clip[6] + clip[7] * 256;
        int right = x + width; int bottom = y + height;
        if (x < clipX) { x = clipX; }
        if (y < clipY) { y = clipY; }
        if (right > clipX + clipWidth) { right = clipX + clipWidth; }
        if (bottom > clipY + clipHeight) { bottom = clipY + clipHeight; }
        if (right <= x || bottom <= y) { return 0; }
        return Paint(x, y, right - x, bottom - y, rgb);
    }

    private static int DrawControl(int x, int y, int color, int kind,
        bool hovered, byte[] clip) {
        int row = 0;
        while (row < 10) {
            int inset = 0;
            if (row == 0 || row == 9) { inset = 3; }
            else if (row == 1 || row == 8) { inset = 1; }
            if (Clip(x + inset, y + row, 10 - inset * 2, 1,
                color, clip) != 0) { return -5; }
            row = row + 1;
        }
        if (hovered) {
            if (kind == 1) {
                int i = 0;
                while (i < 4) {
                    if (Clip(x + 3 + i, y + 3 + i, 1, 1,
                            0xFFFFFF, clip) != 0 ||
                        Clip(x + 6 - i, y + 3 + i, 1, 1,
                            0xFFFFFF, clip) != 0) { return -5; }
                    i = i + 1;
                }
            } else {
                if (Clip(x + 3, y + 5, 4, 1, 0xFFFFFF, clip) != 0) {
                    return -5;
                }
                if (kind == 3 && Clip(x + 5, y + 3, 1, 5,
                    0xFFFFFF, clip) != 0) { return -5; }
            }
        }
        return 0;
    }
    private static int DrawControls(int x, int y, byte[] layout,
        byte[] clip) {
        if (DrawControl(x + 8, y + 8, 0xFF5F57, 1,
                layout[18] == 1, clip) != 0 ||
            DrawControl(x + 28, y + 8, 0xFEBC2E, 2,
                layout[18] == 2, clip) != 0 ||
            DrawControl(x + 48, y + 8, 0x28C840, 3,
                layout[18] == 3, clip) != 0) { return -5; }
        return 0;
    }

    private static int DrawWindow(byte[] layout, byte[] cells,
        byte[] clip, bool focused) {
        int x = Read16(layout, 0); int y = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        int top = ContentTop(layout);
        if (layout[9] == 1) {
            if (Clip(x, y, width, height, 0xE5E8ED, clip) != 0) {
                return -5;
            }
        } else {
            int header = 0xC7CED6;
            if (focused) { header = 0x7DA7CB; }
            if (Clip(x, y + 4, width, height - 8, 0xE5E8ED,
                    clip) != 0 ||
                Clip(x + 4, y, width - 8, 4, 0xE5E8ED,
                    clip) != 0 ||
                Clip(x + 4, y + height - 4, width - 8, 4,
                    0xE5E8ED, clip) != 0 ||
                Clip(x, y + 4, width, 24, header, clip) != 0 ||
                Clip(x + 4, y, width - 8, 4, header, clip) != 0 ||
                DrawControls(x, y, layout, clip) != 0) { return -5; }
        }
        int row = 0;
        while (row < 4) {
            int column = 0;
            while (column < 4) {
                int left = x + 8 + column * (width - 16) / 4;
                int right = x + 8 + (column + 1) * (width - 16) / 4;
                int cellTop = top + row * (y + height - 8 - top) / 4;
                int bottom = top + (row + 1) * (y + height - 8 - top) / 4;
                int cell = (row * 4 + column) * 3;
                int rgb = cells[cell] * 65536 + cells[cell + 1] * 256 +
                    cells[cell + 2];
                if (Clip(left, cellTop, right - left, bottom - cellTop,
                    rgb, clip) != 0) { return -5; }
                column = column + 1;
            }
            row = row + 1;
        }
        return 0;
    }

    private static int Compose(int width, int height, byte[] firstState,
        byte[] firstCells, byte[] firstLayout, byte[] secondState,
        byte[] secondCells, byte[] secondLayout, byte[] clip,
        int focused, int top) {
        if (Clip(0, 0, width, height, 0x26384F, clip) != 0) { return -5; }
        if (top == 1) {
            if (Visible(secondState, secondLayout) &&
                DrawWindow(secondLayout, secondCells, clip,
                    focused == 2) != 0) { return -5; }
            if (Visible(firstState, firstLayout) &&
                DrawWindow(firstLayout, firstCells, clip,
                    focused == 1) != 0) { return -5; }
        } else {
            if (Visible(firstState, firstLayout) &&
                DrawWindow(firstLayout, firstCells, clip,
                    focused == 1) != 0) { return -5; }
            if (Visible(secondState, secondLayout) &&
                DrawWindow(secondLayout, secondCells, clip,
                    focused == 2) != 0) { return -5; }
        }
        int maxId = 0;
        if (top == 1 && Visible(firstState, firstLayout) &&
            firstLayout[9] == 1) { maxId = 1; }
        if (top == 2 && Visible(secondState, secondLayout) &&
            secondLayout[9] == 1) { maxId = 2; }
        int bar = 0x111820;
        if (maxId > 0) { bar = 0x000000; }
        if (Clip(0, 0, width, 32, bar, clip) != 0) { return -5; }
        if (maxId == 1 && DrawControls(0, 2, firstLayout, clip) != 0) {
            return -5;
        }
        if (maxId == 2 && DrawControls(0, 2, secondLayout, clip) != 0) {
            return -5;
        }
        if (firstState[1] == 1) {
            int color = 0xCB3830;
            if (firstLayout[8] == 0) { color = 0x617080; }
            if (Clip(width - 80, 8, 32, 16, color, clip) != 0) {
                return -5;
            }
        }
        if (secondState[1] == 1) {
            int color = 0x2A68D9;
            if (secondLayout[8] == 0) { color = 0x617080; }
            if (Clip(width - 44, 8, 32, 16, color, clip) != 0) {
                return -5;
            }
        }
        return 0;
    }

    private static int Cursor(int x, int y) {
        int row = 0;
        while (row < 14) {
            int span = row / 2 + 2;
            if (Paint(x, y + row, span, 1, 0x101820) != 0) { return -5; }
            if (span > 2 && Paint(x + 1, y + row, span - 2, 1,
                0xFFFFFF) != 0) { return -5; }
            row = row + 1;
        }
        if (Paint(x + 3, y + 14, 3, 6, 0x101820) != 0 ||
            Paint(x + 4, y + 14, 1, 5, 0xFFFFFF) != 0) { return -5; }
        return 0;
    }

    // Version 2: create [1,R,G,B], update [2,id,col,row,R,G,B],
    // close [3,id]. The kernel binds each channel to one child PID.
    // A client can update only the ID assigned to its own channel.
    private static int Handle(int channel, int id, byte[] state, byte[] cells,
        byte[] message, byte[] reply) {
        if (System.Australis.Channel.Peer(channel) < 1) {
            if (state[1] == 1) { state[1] = 0; return 1; }
            return 0;
        }
        int length = System.Australis.Channel.Receive(channel, message);
        if (length < 1) { return 0; }
        reply[0] = message[0]; reply[1] = 0;
        int changed = 0;
        if (length == 4 && message[0] == 1 && state[1] == 0) {
            int i = 0;
            while (i < 16) {
                cells[i * 3] = message[1]; cells[i * 3 + 1] = message[2];
                cells[i * 3 + 2] = message[3]; i = i + 1;
            }
            state[0] = (byte)id; state[1] = 1; state[3] = 0;
            reply[1] = (byte)id; changed = 1;
        } else if (length == 7 && message[0] == 2) {
            if (state[1] == 1 && message[1] == id &&
                message[2] < 4 && message[3] < 4) {
                int cell = (message[3] * 4 + message[2]) * 3;
                cells[cell] = message[4]; cells[cell + 1] = message[5];
                cells[cell + 2] = message[6];
                state[3] = 1; state[6] = message[2]; state[7] = message[3];
                reply[1] = 1; changed = 2;
            } else { state[4] = 1; }
        } else if (length == 2 && message[0] == 3 &&
            message[1] == id && state[1] == 1) {
            state[1] = 0; state[3] = 0; state[5] = 1;
            reply[1] = 1; changed = 1;
        }
        if (System.Australis.Channel.Send(channel, 2, reply) != 0) { return -5; }
        return changed;
    }

    // A bounded list of clipped damage rectangles. If more than sixteen
    // regions accumulate, repaint the screen once.
    private static void Damage(byte[] dirty, int x, int y, int width,
        int height, int displayWidth, int displayHeight) {
        if (width < 1 || height < 1 || x >= displayWidth ||
            y >= displayHeight) { return; }
        if (x < 0) { width = width + x; x = 0; }
        if (y < 0) { height = height + y; y = 0; }
        if (x + width > displayWidth) { width = displayWidth - x; }
        if (y + height > displayHeight) { height = displayHeight - y; }
        if (width < 1 || height < 1) { return; }
        int count = dirty[0];
        if (count == 1 && Read16(dirty, 1) == 0 &&
            Read16(dirty, 3) == 0 &&
            Read16(dirty, 5) == displayWidth &&
            Read16(dirty, 7) == displayHeight) { return; }
        if (x == 0 && y == 0 && width == displayWidth &&
            height == displayHeight) { count = 0; }
        int region = 0;
        while (region < count) {
            int prior = 1 + region * 8;
            int priorX = Read16(dirty, prior);
            int priorY = Read16(dirty, prior + 2);
            int priorWidth = Read16(dirty, prior + 4);
            int priorHeight = Read16(dirty, prior + 6);
            if (priorX <= x && priorY <= y &&
                priorX + priorWidth >= x + width &&
                priorY + priorHeight >= y + height) { return; }
            if (x <= priorX && y <= priorY &&
                x + width >= priorX + priorWidth &&
                y + height >= priorY + priorHeight) {
                int move = region;
                while (move + 1 < count) {
                    int part = 0;
                    while (part < 8) {
                        dirty[1 + move * 8 + part] =
                            dirty[1 + (move + 1) * 8 + part];
                        part = part + 1;
                    }
                    move = move + 1;
                }
                count = count - 1;
            } else { region = region + 1; }
        }
        if (count >= 16) {
            count = 0; x = 0; y = 0;
            width = displayWidth; height = displayHeight;
        }
        int offset = 1 + count * 8;
        dirty[offset] = (byte)(x % 256);
        dirty[offset + 1] = (byte)(x / 256);
        dirty[offset + 2] = (byte)(y % 256);
        dirty[offset + 3] = (byte)(y / 256);
        dirty[offset + 4] = (byte)(width % 256);
        dirty[offset + 5] = (byte)(width / 256);
        dirty[offset + 6] = (byte)(height % 256);
        dirty[offset + 7] = (byte)(height / 256);
        dirty[0] = (byte)(count + 1);
    }

    private static void DamageLayout(byte[] dirty, byte[] layout,
        int width, int height) {
        if (layout[8] == 1) {
            Damage(dirty, Read16(layout, 0), Read16(layout, 2),
                Read16(layout, 4), Read16(layout, 6), width, height);
        }
    }
    private static void DamageTransition(byte[] dirty, byte[] before,
        byte[] after, int width, int height) {
        if (before[8] == 0) {
            DamageLayout(dirty, after, width, height); return;
        }
        if (after[8] == 0) {
            DamageLayout(dirty, before, width, height); return;
        }
        int left = Read16(before, 0); int top = Read16(before, 2);
        int right = left + Read16(before, 4);
        int bottom = top + Read16(before, 6);
        int nextX = Read16(after, 0); int nextY = Read16(after, 2);
        if (nextX < left) { left = nextX; }
        if (nextY < top) { top = nextY; }
        if (nextX + Read16(after, 4) > right) {
            right = nextX + Read16(after, 4);
        }
        if (nextY + Read16(after, 6) > bottom) {
            bottom = nextY + Read16(after, 6);
        }
        Damage(dirty, left, top, right - left, bottom - top,
            width, height);
    }
    private static void DamageOverlap(byte[] dirty, byte[] first,
        byte[] second, int width, int height) {
        if (first[8] == 0 || second[8] == 0) { return; }
        int left = Read16(first, 0); int top = Read16(first, 2);
        int right = left + Read16(first, 4);
        int bottom = top + Read16(first, 6);
        int otherX = Read16(second, 0); int otherY = Read16(second, 2);
        if (left < otherX) { left = otherX; }
        if (top < otherY) { top = otherY; }
        if (right > otherX + Read16(second, 4)) {
            right = otherX + Read16(second, 4);
        }
        if (bottom > otherY + Read16(second, 6)) {
            bottom = otherY + Read16(second, 6);
        }
        Damage(dirty, left, top, right - left, bottom - top,
            width, height);
    }
    private static void DamageCell(byte[] dirty, byte[] state, byte[] layout,
        int width, int height) {
        if (!Visible(state, layout)) { return; }
        int x = Read16(layout, 0); int y = Read16(layout, 2);
        int windowWidth = Read16(layout, 4);
        int windowHeight = Read16(layout, 6);
        int contentTop = ContentTop(layout);
        int col = state[6]; int row = state[7];
        int left = x + 8 + col * (windowWidth - 16) / 4;
        int right = x + 8 + (col + 1) * (windowWidth - 16) / 4;
        int top = contentTop + row *
            (y + windowHeight - 8 - contentTop) / 4;
        int bottom = contentTop + (row + 1) *
            (y + windowHeight - 8 - contentTop) / 4;
        Damage(dirty, left, top, right - left, bottom - top, width, height);
    }

    private static bool HitWindow(int x, int y, byte[] state,
        byte[] layout) {
        if (!Visible(state, layout)) { return false; }
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        if (x < left || x >= left + width || y < top ||
            y >= top + height) { return false; }
        if (layout[9] == 0 &&
            (x < left + 4 || x >= left + width - 4) &&
            (y < top + 4 || y >= top + height - 4)) { return false; }
        return true;
    }
    private static int Hit(int x, int y, byte[] firstState,
        byte[] firstLayout, byte[] secondState, byte[] secondLayout,
        int top) {
        if (top == 1) {
            if (HitWindow(x, y, firstState, firstLayout)) { return 1; }
            if (HitWindow(x, y, secondState, secondLayout)) { return 2; }
        } else {
            if (HitWindow(x, y, secondState, secondLayout)) { return 2; }
            if (HitWindow(x, y, firstState, firstLayout)) { return 1; }
        }
        return 0;
    }

    private static bool ContentHit(int x, int y, byte[] layout) {
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        return x >= left + 8 && x < left + width - 8 &&
            y >= ContentTop(layout) && y < top + height - 8;
    }

    private static void HeaderDamage(byte[] dirty, byte[] layout,
        int width, int height) {
        if (layout[8] == 0) { return; }
        if (layout[9] == 1) {
            Damage(dirty, 0, 0, width, 32, width, height);
        } else {
            Damage(dirty, Read16(layout, 0), Read16(layout, 2),
                Read16(layout, 4), 28, width, height);
        }
    }
    private static int MenuHit(int x, int y, int width,
        byte[] firstState, byte[] secondState) {
        if (y < 8 || y >= 24) { return 0; }
        if (x >= width - 80 && x < width - 48 &&
            firstState[1] == 1) { return 1; }
        if (x >= width - 44 && x < width - 12 &&
            secondState[1] == 1) { return 2; }
        return 0;
    }
    private static int ControlHit(int x, int y, byte[] layout) {
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        if (layout[9] == 1) { left = 0; top = 2; }
        if (y < top + 8 || y >= top + 18) { return 0; }
        if (x >= left + 8 && x < left + 18) { return 1; }
        if (x >= left + 28 && x < left + 38) { return 2; }
        if (x >= left + 48 && x < left + 58) { return 3; }
        return 0;
    }
    private static bool ResizeHit(int x, int y, byte[] layout) {
        if (layout[9] == 1) { return false; }
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        int width = Read16(layout, 4); int height = Read16(layout, 6);
        return x >= left + width - 12 || y >= top + height - 12;
    }
    private static bool TitleHit(int x, int y, byte[] layout) {
        if (layout[9] == 1) { return false; }
        int left = Read16(layout, 0); int top = Read16(layout, 2);
        return x >= left + 70 && x < left + Read16(layout, 4) - 12 &&
            y >= top && y < top + 28;
    }

    // Kinds: 1 move, 2 down, 3 up. Coordinates are clipped to the
    // target's content and never name another client's surface.
    private static void Pointer(int id, int kind, int x, int y,
        byte[] firstLayout, byte[] secondLayout,
        int firstChannel, int secondChannel, byte[] event) {
        if (id < 1) { return; }
        byte[] layout = firstLayout; int channel = firstChannel;
        if (id == 2) {
            layout = secondLayout; channel = secondChannel;
        }
        int localX = x - Read16(layout, 0) - 8;
        int localY = y - ContentTop(layout);
        if (localX < 0) { localX = 0; }
        if (localY < 0) { localY = 0; }
        int maxX = Read16(layout, 4) - 17;
        int maxY = Read16(layout, 2) + Read16(layout, 6) - 9 -
            ContentTop(layout);
        if (localX > maxX) { localX = maxX; }
        if (localY > maxY) { localY = maxY; }
        event[0] = 4; event[1] = (byte)id; event[2] = (byte)kind;
        event[3] = (byte)(localX % 256);
        event[4] = (byte)(localX / 256);
        event[5] = (byte)(localY % 256);
        event[6] = (byte)(localY / 256);
        int sent = System.Australis.Channel.Send(channel, 2, event);
    }

    private static int Flush(byte[] dirty, byte[] clip, int width,
        int height, byte[] firstState, byte[] firstCells,
        byte[] firstLayout, byte[] secondState, byte[] secondCells,
        byte[] secondLayout, int focused, int top, int cursorX,
        int cursorY) {
        int count = dirty[0];
        int i = 0;
        while (i < count) {
            int offset = 1 + i * 8;
            int x = dirty[offset] + dirty[offset + 1] * 256;
            int y = dirty[offset + 2] + dirty[offset + 3] * 256;
            int rectWidth = dirty[offset + 4] + dirty[offset + 5] * 256;
            int rectHeight = dirty[offset + 6] + dirty[offset + 7] * 256;
            SetClip(clip, x, y, rectWidth, rectHeight);
            if (Compose(width, height, firstState, firstCells,
                firstLayout, secondState, secondCells, secondLayout,
                clip, focused, top) != 0) { return -5; }
            if (x < cursorX + 14 && x + rectWidth > cursorX &&
                y < cursorY + 20 && y + rectHeight > cursorY &&
                Cursor(cursorX, cursorY) != 0) { return -5; }
            i = i + 1;
        }
        dirty[0] = 0;
        return 0;
    }

    public static int Main(string[] args) {
        int width = System.Australis.SystemInfo.Query(23);
        int height = System.Australis.SystemInfo.Query(24);
        if (width < 320 || width > 2048 || height < 240 ||
            height > 2048 || width * height > 1048576) { return 1; }
        if (System.Australis.Display.Acquire() != 0) { return 2; }
        if (System.Australis.Display.SetMode(width, height) != -95) {
            int released = System.Australis.Display.Release(); return 8;
        }
        int firstPid = System.Australis.Process.Spawn(
            "/System/Core/DisplayDemoA.exec");
        int secondPid = System.Australis.Process.Spawn(
            "/System/Core/DisplayDemoB.exec");
        if (firstPid < 1 || secondPid < 1) {
            int released = System.Australis.Display.Release(); return 3;
        }
        int firstChannel = System.Australis.Channel.Open(firstPid, 2);
        int secondChannel = System.Australis.Channel.Open(secondPid, 2);
        if (firstChannel < 1 || secondChannel < 1) {
            int released = System.Australis.Display.Release(); return 4;
        }
        byte[] firstState = new byte[8]; byte[] secondState = new byte[8];
        byte[] firstCells = new byte[48]; byte[] secondCells = new byte[48];
        byte[] message = new byte[7]; byte[] reply = new byte[2];
        int rounds = 0;
        while (rounds < 1000 && (firstState[3] == 0 || secondState[3] == 0 ||
            firstState[4] == 0 || secondState[4] == 0 ||
            secondState[5] == 0)) {
            if (Handle(firstChannel, 1, firstState, firstCells,
                    message, reply) < 0 ||
                Handle(secondChannel, 2, secondState, secondCells,
                    message, reply) < 0) {
                int released = System.Australis.Display.Release(); return 5;
            }
            int slept = System.Australis.Process.Sleep(1);
            rounds = rounds + 1;
        }
        if (firstState[1] != 1 || secondState[1] != 1 ||
            firstState[3] == 0 || secondState[3] == 0 ||
            firstState[4] == 0 || secondState[4] == 0 ||
            secondState[5] == 0) {
            int released = System.Australis.Display.Release(); return 5;
        }
        int windowWidth = width / 2 - 30;
        int windowHeight = height / 2;
        if (windowWidth < 96 || windowHeight < 80 ||
            width / 3 + windowWidth > width ||
            72 + windowHeight > height) {
            int released = System.Australis.Display.Release(); return 6;
        }
        byte[] firstLayout = new byte[19];
        byte[] secondLayout = new byte[19];
        byte[] beforeFirst = new byte[19];
        byte[] beforeSecond = new byte[19];
        InitLayout(firstLayout, 20, 48, windowWidth, windowHeight);
        InitLayout(secondLayout, width / 3, 72, windowWidth, windowHeight);
        byte[] clip = new byte[8];
        SetClip(clip, 0, 0, width, height);
        int cursorX = width / 2; int cursorY = height / 2;
        if (Compose(width, height, firstState, firstCells,
            firstLayout, secondState, secondCells, secondLayout,
            clip, 0, 2) != 0 ||
            Cursor(cursorX, cursorY) != 0) {
            int released = System.Australis.Display.Release(); return 6;
        }
        System.Console.WriteLine("Display: two client windows composed; cursor ready");
        System.Console.WriteLine("Display: cross-window denial and close/reopen verified");
        if (System.Australis.Process.Ready() != 0) {
            int released = System.Australis.Display.Release(); return 7;
        }
        byte[] mouse = new byte[3];
        byte[] dirty = new byte[129];
        byte[] pointerEvent = new byte[7];
        byte[] keyEvent = new byte[3];
        int focused = 0; int top = 2; int captured = 0; int buttons = 0;
        int dragKind = 0; int dragId = 0;
        int failure = 0;
        while (true) {
            int changed = Handle(firstChannel, 1, firstState, firstCells,
                message, reply);
            int other = Handle(secondChannel, 2, secondState, secondCells,
                message, reply);
            if (changed < 0 || other < 0) {
                System.Console.WriteLine("Display: channel failure");
                failure = 8; break;
            }
            if (changed == 1) {
                Damage(dirty, 0, 0, width, height, width, height);
            } else if (changed == 2) {
                DamageCell(dirty, firstState, firstLayout, width, height);
            }
            if (other == 1) {
                Damage(dirty, 0, 0, width, height, width, height);
            } else if (other == 2) {
                DamageCell(dirty, secondState, secondLayout, width, height);
            }
            if ((focused == 1 && !Visible(firstState, firstLayout)) ||
                (focused == 2 && !Visible(secondState, secondLayout))) {
                if (focused == 1) {
                    HeaderDamage(dirty, firstLayout, width, height);
                } else { HeaderDamage(dirty, secondLayout, width, height); }
                focused = 0; captured = 0; dragKind = 0; dragId = 0;
                if (Visible(firstState, firstLayout)) { focused = 1; top = 1; }
                if (Visible(secondState, secondLayout)) { focused = 2; top = 2; }
                int capture = 0;
                if (focused > 0) { capture = 1; }
                if (System.Australis.Display.CaptureKeyboard(capture) != 0) {
                    System.Console.WriteLine("Display: keyboard release failure");
                    failure = 9; break;
                }
            }
            CopyLayout(firstLayout, beforeFirst);
            CopyLayout(secondLayout, beforeSecond);
            int beforeTop = top; int beforeFocus = focused;
            int originalX = cursorX; int originalY = cursorY;
            int moves = 0; int inputFailure = 0;
            while (moves < 16) {
                int mouseResult = System.Australis.Display.PollMouse(mouse);
                if (mouseResult == -1) { break; }
                if (mouseResult != 3) {
                    System.Console.WriteLine("Display: mouse input failure");
                    inputFailure = 1; break;
                }
                int nextX = cursorX + mouse[1] - 128;
                int nextY = cursorY + mouse[2] - 128;
                if (nextX < 0) { nextX = 0; }
                if (nextY < 0) { nextY = 0; }
                if (nextX > width - 14) { nextX = width - 14; }
                if (nextY > height - 20) { nextY = height - 20; }
                int deltaX = nextX - cursorX;
                int deltaY = nextY - cursorY;
                cursorX = nextX; cursorY = nextY;
                int nextButtons = mouse[0] % 2;
                if (nextButtons == 1 && buttons == 0) {
                    int previousFocus = focused;
                    captured = 0; dragKind = 0; dragId = 0;
                    int menu = MenuHit(cursorX, cursorY, width,
                        firstState, secondState);
                    if (menu > 0) {
                        byte[] selected = firstLayout;
                        if (menu == 2) { selected = secondLayout; }
                        selected[8] = 1;
                        top = menu; focused = menu;
                    } else {
                        int hit = Hit(cursorX, cursorY, firstState,
                            firstLayout, secondState, secondLayout, top);
                        if (cursorY < 32) {
                            byte[] active = firstLayout;
                            byte[] activeState = firstState;
                            if (top == 2) {
                                active = secondLayout;
                                activeState = secondState;
                            }
                            if (Visible(activeState, active) &&
                                active[9] == 1 &&
                                ControlHit(cursorX, cursorY, active) > 0) {
                                hit = top;
                            }
                        }
                        focused = hit;
                        if (hit > 0) {
                            top = hit;
                            byte[] selected = firstLayout;
                            if (hit == 2) { selected = secondLayout; }
                            int control = ControlHit(cursorX, cursorY,
                                selected);
                            if (control == 1) {
                                int pid = firstPid;
                                if (hit == 2) { pid = secondPid; }
                                if (System.Australis.Process.Terminate(pid) != 0) {
                                    inputFailure = 1; break;
                                }
                                selected[8] = 0;
                                if (hit == 1) { firstState[1] = 0; }
                                else { secondState[1] = 0; }
                                focused = 0;
                                if (Visible(firstState, firstLayout)) {
                                    focused = 1; top = 1;
                                }
                                if (Visible(secondState, secondLayout)) {
                                    focused = 2; top = 2;
                                }
                            } else if (control == 2) {
                                selected[8] = 0;
                                focused = 0;
                                if (Visible(firstState, firstLayout)) {
                                    focused = 1; top = 1;
                                }
                                if (Visible(secondState, secondLayout)) {
                                    focused = 2; top = 2;
                                }
                            } else if (control == 3) {
                                ToggleMax(selected, width, height);
                            } else if (ResizeHit(cursorX, cursorY,
                                selected)) {
                                dragKind = 2; dragId = hit;
                            } else if (TitleHit(cursorX, cursorY,
                                selected)) {
                                dragKind = 1; dragId = hit;
                            } else if (ContentHit(cursorX, cursorY,
                                selected)) {
                                captured = hit;
                                Pointer(hit, 2, cursorX, cursorY,
                                    firstLayout, secondLayout, firstChannel,
                                    secondChannel, pointerEvent);
                            }
                        }
                    }
                    if (focused != previousFocus) {
                        int capture = 0;
                        if (focused > 0) { capture = 1; }
                        if (System.Australis.Display.CaptureKeyboard(capture) != 0) {
                            System.Console.WriteLine("Display: keyboard capture failure");
                            inputFailure = 1; break;
                        }
                    }
                } else if (nextButtons == 1 && buttons == 1) {
                    if (dragKind > 0 && dragId > 0 &&
                        (deltaX != 0 || deltaY != 0)) {
                        byte[] selected = firstLayout;
                        if (dragId == 2) { selected = secondLayout; }
                        int x = Read16(selected, 0);
                        int y = Read16(selected, 2);
                        int windowWidth = Read16(selected, 4);
                        int windowHeight = Read16(selected, 6);
                        if (dragKind == 1) {
                            x = x + deltaX; y = y + deltaY;
                            if (x < 0) { x = 0; }
                            if (y < 32) { y = 32; }
                            if (x + windowWidth > width) {
                                x = width - windowWidth;
                            }
                            if (y + windowHeight > height) {
                                y = height - windowHeight;
                            }
                            Write16(selected, 0, x); Write16(selected, 2, y);
                        } else {
                            windowWidth = windowWidth + deltaX;
                            windowHeight = windowHeight + deltaY;
                            if (windowWidth < 96) { windowWidth = 96; }
                            if (windowHeight < 80) { windowHeight = 80; }
                            if (x + windowWidth > width) {
                                windowWidth = width - x;
                            }
                            if (y + windowHeight > height) {
                                windowHeight = height - y;
                            }
                            Write16(selected, 4, windowWidth);
                            Write16(selected, 6, windowHeight);
                        }
                    } else if (captured > 0 &&
                        (deltaX != 0 || deltaY != 0)) {
                        Pointer(captured, 1, cursorX, cursorY,
                            firstLayout, secondLayout, firstChannel,
                            secondChannel, pointerEvent);
                    }
                } else if (nextButtons == 0 && buttons == 1) {
                    if (captured > 0) {
                        Pointer(captured, 3, cursorX, cursorY,
                            firstLayout, secondLayout, firstChannel,
                            secondChannel, pointerEvent);
                    }
                    captured = 0; dragKind = 0; dragId = 0;
                }
                buttons = nextButtons;
                moves = moves + 1;
            }
            if (inputFailure != 0) { failure = 9; break; }
            int hoverHit = Hit(cursorX, cursorY, firstState,
                firstLayout, secondState, secondLayout, top);
            if (cursorY < 32) {
                byte[] active = firstLayout;
                byte[] activeState = firstState;
                if (top == 2) {
                    active = secondLayout; activeState = secondState;
                }
                if (Visible(activeState, active) && active[9] == 1 &&
                    ControlHit(cursorX, cursorY, active) > 0) {
                    hoverHit = top;
                }
            }
            firstLayout[18] = 0; secondLayout[18] = 0;
            if (hoverHit == 1) {
                firstLayout[18] = (byte)ControlHit(cursorX, cursorY,
                    firstLayout);
            }
            if (hoverHit == 2) {
                secondLayout[18] = (byte)ControlHit(cursorX, cursorY,
                    secondLayout);
            }
            if (LayoutChanged(beforeFirst, firstLayout)) {
                DamageTransition(dirty, beforeFirst, firstLayout,
                    width, height);
                if (beforeFirst[9] != firstLayout[9]) {
                    Damage(dirty, 0, 0, width, 32, width, height);
                }
            }
            if (LayoutChanged(beforeSecond, secondLayout)) {
                DamageTransition(dirty, beforeSecond, secondLayout,
                    width, height);
                if (beforeSecond[9] != secondLayout[9]) {
                    Damage(dirty, 0, 0, width, 32, width, height);
                }
            }
            if (beforeTop != top) {
                DamageOverlap(dirty, firstLayout, secondLayout,
                    width, height);
                Damage(dirty, 0, 0, width, 32, width, height);
            }
            if (beforeFocus != focused) {
                if (beforeFocus == 1) {
                    HeaderDamage(dirty, beforeFirst, width, height);
                }
                if (beforeFocus == 2) {
                    HeaderDamage(dirty, beforeSecond, width, height);
                }
                if (focused == 1) {
                    HeaderDamage(dirty, firstLayout, width, height);
                }
                if (focused == 2) {
                    HeaderDamage(dirty, secondLayout, width, height);
                }
            }
            if (beforeFirst[18] != firstLayout[18]) {
                HeaderDamage(dirty, firstLayout, width, height);
            }
            if (beforeSecond[18] != secondLayout[18]) {
                HeaderDamage(dirty, secondLayout, width, height);
            }
            if (cursorX != originalX || cursorY != originalY) {
                // Only the original cursor reached the framebuffer. Reports
                // between it and the final position do not need restoring.
                Damage(dirty, originalX, originalY, 14, 20, width, height);
                Damage(dirty, cursorX, cursorY, 14, 20, width, height);
            }
            if (dirty[0] > 0 && Flush(dirty, clip, width, height,
                firstState, firstCells, firstLayout, secondState,
                secondCells, secondLayout, focused, top,
                cursorX, cursorY) != 0) {
                System.Console.WriteLine("Display: redraw failure");
                failure = 10; break;
            }
            if (focused > 0) {
                int keys = 0;
                while (keys < 8) {
                    int key = System.Australis.Display.PollKey();
                    if (key == -1) { break; }
                    if (key < -1) {
                        System.Console.WriteLine("Display: keyboard input failure");
                        failure = 11; break;
                    }
                    if (key <= 255) {
                        keyEvent[0] = 5; keyEvent[1] = (byte)focused;
                        keyEvent[2] = (byte)key;
                        int channel = firstChannel;
                        if (focused == 2) { channel = secondChannel; }
                        int sent = System.Australis.Channel.Send(channel, 2,
                            keyEvent);
                    }
                    keys = keys + 1;
                }
            }
            if (failure != 0) { break; }
            int slept = System.Australis.Process.Sleep(10);
            if (slept != 0) {
                System.Console.WriteLine("Display: sleep failure");
                failure = 12; break;
            }
        }
        int released = System.Australis.Display.Release();
        if (released != 0 && failure == 0) { failure = 13; }
        return failure;
    }
}
