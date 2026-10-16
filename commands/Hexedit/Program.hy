public class Program {
    private static void Bar(string label, string path, bool dirty,
        byte[] row, byte[] reverse, byte[] normal) {
        int i = 0;
        while (i < row.Length) { row[i] = 32; i = i + 1; }
        i = 0;
        while (i < label.Length && i < row.Length) {
            row[i] = (byte)System.Australis.Text.ByteAt(label, i); i = i + 1;
        }
        int j = 0;
        while (j < path.Length && i < row.Length - 1) {
            row[i] = (byte)System.Australis.Text.ByteAt(path, j);
            i = i + 1; j = j + 1;
        }
        if (dirty) { row[row.Length - 1] = 42; }
        System.Console.WriteBytes(reverse); System.Console.WriteBytes(row);
        System.Console.WriteBytes(normal); System.Console.WriteLine();
    }

    private static int Digit(int value) {
        if (value < 10) { return 48 + value; }
        return 55 + value;
    }
    private static int Hex(int value) {
        if (value >= 48 && value <= 57) { return value - 48; }
        if (value >= 65 && value <= 70) { return value - 55; }
        if (value >= 97 && value <= 102) { return value - 87; }
        return -1;
    }
    private static string SaveMessage(int result) {
        if (result == 0) { return "Saved"; }
        if (result == 8) { return "Read-only volume. Use ^O to save under /data."; }
        if (result == 4) { return "Directory does not exist"; }
        if (result == 11) { return "No space left on volume"; }
        if (result == 1) { return "Path is not a regular file"; }
        return "Save failed (storage error)";
    }
    private static string PromptPath(byte[] pathBytes, byte[] one, byte[] clear) {
        int length = 0;
        while (true) {
            System.Australis.Terminal.MoveCursor(20, 1);
            System.Console.WriteBytes(clear);
            System.Australis.Terminal.MoveCursor(20, 1);
            System.Console.Write("Save as: ");
            int i = 0;
            while (i < length) {
                one[0] = pathBytes[i]; System.Console.WriteBytes(one); i = i + 1;
            }
            int key = System.Australis.Terminal.ReadKey();
            if (key == 7 || key < 0) { return ""; }
            if (key == 13 || key == 10) {
                if (length == 0) { return ""; }
                return System.Australis.Text.FromBytes(pathBytes, length);
            }
            if ((key == 8 || key == 127) && length > 0) { length = length - 1; }
            else if (key >= 32 && key <= 126 && length < 255) {
                pathBytes[length] = (byte)key; length = length + 1;
            }
        }
        return "";
    }
    private static void Render(string path, byte[] data, int length, int cursor,
        bool lowNibble, bool dirty, string status, byte[] row,
        byte[] reverse, byte[] normal) {
        int page = cursor / 256;
        System.Australis.Terminal.Clear();
        Bar(" AUSTRALIS HEXEDIT  ", path, dirty, row, reverse, normal);
        int line = 0;
        while (line < 16) {
            int i = 0;
            while (i < row.Length) { row[i] = 32; i = i + 1; }
            int offset = page * 256 + line * 16;
            row[0] = (byte)Digit((offset / 4096) % 16);
            row[1] = (byte)Digit((offset / 256) % 16);
            row[2] = (byte)Digit((offset / 16) % 16);
            row[3] = (byte)Digit(offset % 16);
            row[4] = 58;
            i = 0;
            while (i < 16 && offset + i < length) {
                int value = data[offset + i];
                row[6 + i * 3] = (byte)Digit(value / 16);
                row[7 + i * 3] = (byte)Digit(value % 16);
                if (value >= 32 && value <= 126) { row[56 + i] = (byte)value; }
                else { row[56 + i] = 46; }
                i = i + 1;
            }
            if (offset + i == length && i < 16) {
                row[6 + i * 3] = 95; row[7 + i * 3] = 95;
            }
            System.Console.WriteBytes(row); System.Console.WriteLine();
            line = line + 1;
        }
        Bar("^S Save  ^O Save As  ^X Exit  Hex digits edit  Arrows move",
            "", false, row, reverse, normal);
        System.Console.Write(" "); System.Console.Write(status);
        System.Console.Write("  offset "); System.Console.WriteLine(cursor);
        int column = 7 + (cursor % 16) * 3;
        if (lowNibble) { column = column + 1; }
        System.Australis.Terminal.MoveCursor(2 + (cursor % 256) / 16, column);
    }
    public static int Main(string[] args) {
        if (args.Length != 1) { System.Console.WriteLine("Usage: hexedit <file>"); return 2; }
        byte[] data = new byte[4096]; byte[] chunk = new byte[128];
        byte[] row = new byte[72]; string path = args[0];
        byte[] pathBytes = new byte[255]; byte[] one = new byte[1];
        byte[] clear = new byte[72];
        byte[] reverse = new byte[4]; byte[] normal = new byte[4];
        reverse[0] = 27; reverse[1] = 91; reverse[2] = 55; reverse[3] = 109;
        normal[0] = 27; normal[1] = 91; normal[2] = 48; normal[3] = 109;
        int i = 0; while (i < clear.Length) { clear[i] = 32; i = i + 1; }
        int length = EditorStorage.Load(path, data, chunk);
        if (length == -2) { System.Console.WriteLine("hexedit: file exceeds 4096 bytes"); return 2; }
        if (length < 0) { System.Console.WriteLine("hexedit: cannot open file"); return 3; }
        int cursor = 0; bool lowNibble = false; bool dirty = false;
        string status = "Ready";
        while (true) {
            Render(path, data, length, cursor, lowNibble, dirty, status, row,
                reverse, normal);
            int key = System.Australis.Terminal.ReadKey();
            status = "Ready";
            if (key < 0) { return 0; }
            if (key == 19) {
                int result = EditorStorage.Save(path, data, length, chunk);
                status = SaveMessage(result);
                if (result == 0) { dirty = false; }
            } else if (key == 15) {
                string destination = PromptPath(pathBytes, one, clear);
                if (destination != "") {
                    int result = EditorStorage.Save(destination, data, length, chunk);
                    status = SaveMessage(result);
                    if (result == 0) { path = destination; dirty = false; }
                }
            } else if (key == 24) {
                if (!dirty) { System.Australis.Terminal.Clear(); return 0; }
                System.Australis.Terminal.MoveCursor(20, 1);
                System.Console.Write("Save changes? Y save, N discard, ^G cancel: ");
                int choice = System.Australis.Terminal.ReadKey();
                if (choice == 110 || choice == 78) {
                    System.Australis.Terminal.Clear(); return 0;
                }
                if (choice == 121 || choice == 89) {
                    int result = EditorStorage.Save(path, data, length, chunk);
                    status = SaveMessage(result);
                    if (result == 0) { System.Australis.Terminal.Clear(); return 0; }
                }
            } else if (key == 258 && cursor < length) {
                cursor = cursor + 1; lowNibble = false;
            } else if (key == 259 && cursor > 0) {
                cursor = cursor - 1; lowNibble = false;
            } else if (key == 256 && cursor >= 16) {
                cursor = cursor - 16; lowNibble = false;
            } else if (key == 257 && cursor + 16 <= length) {
                cursor = cursor + 16; lowNibble = false;
            } else if (key == 260) {
                cursor = (cursor / 16) * 16; lowNibble = false;
            } else if (key == 261) {
                cursor = (cursor / 16) * 16 + 15;
                if (cursor > length) { cursor = length; }
                lowNibble = false;
            } else if (key == 262 && cursor < length) {
                int i = cursor;
                while (i + 1 < length) { data[i] = data[i + 1]; i = i + 1; }
                length = length - 1; lowNibble = false; dirty = true;
            } else if ((key == 8 || key == 127) && cursor > 0) {
                cursor = cursor - 1;
                int i = cursor;
                while (i + 1 < length) { data[i] = data[i + 1]; i = i + 1; }
                length = length - 1; lowNibble = false; dirty = true;
            } else {
                int nibble = Hex(key);
                if (nibble >= 0) {
                    if (cursor == data.Length) { status = "Buffer full (4096 bytes)"; }
                    else {
                        if (cursor == length) { data[cursor] = 0; length = length + 1; }
                        if (lowNibble) {
                            data[cursor] = (byte)((data[cursor] / 16) * 16 + nibble);
                            lowNibble = false;
                            if (cursor < length) { cursor = cursor + 1; }
                        } else {
                            data[cursor] = (byte)(nibble * 16 + data[cursor] % 16);
                            lowNibble = true;
                        }
                        dirty = true;
                    }
                }
            }
        }
        return 0;
    }
}
