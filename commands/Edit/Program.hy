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

    private static int LineNumber(byte[] data, int cursor) {
        int line = 0; int i = 0;
        while (i < cursor) { if (data[i] == 10) { line = line + 1; } i = i + 1; }
        return line;
    }

    private static int LineStart(byte[] data, int length, int line) {
        if (line == 0) { return 0; }
        int found = 0; int i = 0;
        while (i < length) {
            if (data[i] == 10) {
                found = found + 1;
                if (found == line) { return i + 1; }
            }
            i = i + 1;
        }
        return -1;
    }

    private static int LineEnd(byte[] data, int length, int start) {
        int i = start;
        while (i < length && data[i] != 10) { i = i + 1; }
        return i;
    }

    private static int Column(byte[] data, int cursor) {
        int i = cursor - 1;
        while (i >= 0 && data[i] != 10) { i = i - 1; }
        return cursor - i - 1;
    }

    private static int Vertical(byte[] data, int length, int cursor, int direction) {
        int target = LineNumber(data, cursor) + direction;
        if (target < 0) { return cursor; }
        int start = LineStart(data, length, target);
        if (start < 0) { return cursor; }
        int end = LineEnd(data, length, start);
        int position = start + Column(data, cursor);
        if (position > end) { position = end; }
        return position;
    }

    private static void Render(string path, byte[] data, int length, int cursor,
        int top, int left, bool dirty, string status, byte[] row,
        byte[] reverse, byte[] normal) {
        System.Australis.Terminal.Clear();
        Bar(" AUSTRALIS EDIT  ", path, dirty, row, reverse, normal);
        int line = 0;
        while (line < 20) {
            int i = 0;
            while (i < row.Length) { row[i] = 32; i = i + 1; }
            int start = LineStart(data, length, top + line);
            if (start >= 0) {
                int end = LineEnd(data, length, start);
                int column = 0;
                while (column < row.Length && start + left + column < end) {
                    int value = data[start + left + column];
                    if (value < 32 || value > 126) { value = 46; }
                    row[column] = (byte)value; column = column + 1;
                }
            }
            System.Console.WriteBytes(row); System.Console.WriteLine();
            line = line + 1;
        }
        Bar("^S Save  ^O Save As  ^X Exit  Arrows move  Del removes",
            "", false, row, reverse, normal);
        System.Console.Write(" "); System.Console.Write(status); System.Console.Write("  ");
        System.Console.Write(LineNumber(data, cursor) + 1); System.Console.Write(":");
        System.Console.WriteLine(Column(data, cursor) + 1);
        int screenRow = LineNumber(data, cursor) - top + 2;
        int screenColumn = Column(data, cursor) - left + 1;
        System.Australis.Terminal.MoveCursor(screenRow, screenColumn);
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
            System.Australis.Terminal.MoveCursor(24, 1);
            System.Console.WriteBytes(clear);
            System.Australis.Terminal.MoveCursor(24, 1);
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

    public static int Main(string[] args) {
        if (args.Length != 1) { System.Console.WriteLine("Usage: edit <file>"); return 2; }
        byte[] data = new byte[4096]; byte[] chunk = new byte[128];
        byte[] row = new byte[60]; byte[] pathBytes = new byte[255];
        byte[] one = new byte[1]; byte[] clear = new byte[60];
        byte[] reverse = new byte[4]; byte[] normal = new byte[4];
        reverse[0] = 27; reverse[1] = 91; reverse[2] = 55; reverse[3] = 109;
        normal[0] = 27; normal[1] = 91; normal[2] = 48; normal[3] = 109;
        int i = 0; while (i < clear.Length) { clear[i] = 32; i = i + 1; }
        string path = args[0];
        int length = EditorStorage.Load(path, data, chunk);
        if (length == -2) { System.Console.WriteLine("edit: file exceeds 4096 bytes"); return 2; }
        if (length < 0) { System.Console.WriteLine("edit: cannot open file"); return 3; }
        int cursor = 0; int top = 0; int left = 0;
        bool dirty = false; string status = "Ready";
        while (true) {
            int line = LineNumber(data, cursor); int column = Column(data, cursor);
            if (line < top) { top = line; }
            if (line >= top + 20) { top = line - 19; }
            if (column < left) { left = column; }
            if (column >= left + 60) { left = column - 59; }
            Render(path, data, length, cursor, top, left, dirty, status, row,
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
                System.Australis.Terminal.MoveCursor(24, 1);
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
            } else if (key == 256) { cursor = Vertical(data, length, cursor, -1); }
            else if (key == 257) { cursor = Vertical(data, length, cursor, 1); }
            else if (key == 258 && cursor < length) { cursor = cursor + 1; }
            else if (key == 259 && cursor > 0) { cursor = cursor - 1; }
            else if (key == 260) { cursor = cursor - column; }
            else if (key == 261) { cursor = LineEnd(data, length, cursor - column); }
            else if ((key == 8 || key == 127) && cursor > 0) {
                i = cursor - 1;
                while (i + 1 < length) { data[i] = data[i + 1]; i = i + 1; }
                cursor = cursor - 1; length = length - 1; dirty = true;
            } else if (key == 262 && cursor < length) {
                i = cursor;
                while (i + 1 < length) { data[i] = data[i + 1]; i = i + 1; }
                length = length - 1; dirty = true;
            } else if (key == 13 || key == 10 || (key >= 32 && key <= 126)) {
                if (length == data.Length) { status = "Buffer full (4096 bytes)"; }
                else {
                    i = length;
                    while (i > cursor) { data[i] = data[i - 1]; i = i - 1; }
                    if (key == 13) { key = 10; }
                    data[cursor] = (byte)key;
                    cursor = cursor + 1; length = length + 1; dirty = true;
                }
            }
        }
        return 0;
    }
}
