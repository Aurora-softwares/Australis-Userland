public class Program {
    private static int Get16(byte[] values, int index) {
        return values[index * 2] + values[index * 2 + 1] * 256;
    }

    private static void Set16(byte[] values, int index, int value) {
        values[index * 2] = (byte)(value % 256);
        values[index * 2 + 1] = (byte)(value / 256);
    }

    public static int Main(string[] args) {
        if (args.Length > 1) {
            System.Console.WriteLine("Usage: tree [directory]"); return 2;
        }
        string root = "/";
        if (args.Length == 1) { root = args[0]; }
        if (System.Australis.Files.StatKind(root) != 2) {
            System.Console.WriteLine("tree: directory not found"); return 2;
        }
        int length = root.Length;
        if (length < 1 || length > 255) { return 2; }
        byte[] path = new byte[256];
        byte[] name = new byte[64];
        byte[] lengths = new byte[128];
        byte[] indexes = new byte[256];
        byte[] counts = new byte[256];
        int i = 0;
        while (i < length) {
            path[i] = (byte)System.Australis.Text.ByteAt(root, i);
            i = i + 1;
        }
        path[length] = 0;
        int firstCount = System.Australis.Files.DirectoryCount(root);
        if (firstCount < 0 || firstCount > 65535) {
            System.Console.WriteLine("tree: cannot read root directory"); return 2;
        }
        System.Console.WriteLine(root);
        int depth = 0;
        lengths[0] = (byte)length;
        Set16(indexes, 0, 0);
        Set16(counts, 0, firstCount);
        while (depth >= 0) {
            int index = Get16(indexes, depth);
            int count = Get16(counts, depth);
            if (index >= count) {
                depth = depth - 1;
                if (depth >= 0) {
                    length = lengths[depth];
                    path[length] = 0;
                }
                continue;
            }
            Set16(indexes, depth, index + 1);
            string directory = System.Australis.Text.FromBytes(path, length);
            int nameLength = System.Australis.Files.DirectoryNameInto(directory,
                index, name);
            if (nameLength < 0) {
                System.Console.WriteLine("tree: directory entry failed"); return 3;
            }
            int previousLength = length;
            if (length > 1) {
                if (length >= 255) { return 3; }
                path[length] = 47; length = length + 1;
            }
            if (nameLength > 255 - length) {
                System.Console.WriteLine("tree: path too long"); return 3;
            }
            i = 0;
            while (i < nameLength) {
                path[length] = name[i]; length = length + 1; i = i + 1;
            }
            path[length] = 0;
            string child = System.Australis.Text.FromBytes(path, length);
            int kind = System.Australis.Files.StatKind(child);
            if (kind < 0) {
                System.Console.WriteLine("tree: entry changed during traversal"); return 3;
            }
            int indent = 0;
            while (indent < depth) {
                System.Console.Write("  "); indent = indent + 1;
            }
            System.Console.Write(System.Australis.Text.FromBytes(name, nameLength));
            if (kind == 2) { System.Console.WriteLine("/"); }
            else { System.Console.WriteLine(); }
            if (kind == 2) {
                int childCount = System.Australis.Files.DirectoryCount(child);
                if (childCount < 0 || childCount > 65535 || depth >= 127) {
                    System.Console.WriteLine("tree: cannot descend into directory"); return 3;
                }
                depth = depth + 1;
                lengths[depth] = (byte)length;
                Set16(indexes, depth, 0);
                Set16(counts, depth, childCount);
            } else {
                length = previousLength;
                path[length] = 0;
            }
        }
        return 0;
    }
}
