public class Program {
    public static int Main(string[] args) {
        if (args.Length > 1) {
            System.Console.WriteLine("Usage: ls [path]");
            return 2;
        }
        if (System.Australis.Files.ApiVersion() != 1) {
            System.Console.WriteLine("ls: unsupported file API");
            return 3;
        }
        string path = "/";
        if (args.Length == 1) { path = args[0]; }
        int kind = System.Australis.Files.StatKind(path);
        if (kind < 0) {
            System.Console.WriteLine("ls: stat failed (status):");
            System.Console.WriteLine(System.Australis.Files.Status());
            return System.Australis.Files.Status();
        }
        if (kind == 1) {
            System.Console.WriteLine(path);
            return 0;
        }
        if (kind != 2) {
            System.Console.WriteLine("ls: unsupported entry kind");
            return 4;
        }
        int count = System.Australis.Files.DirectoryCount(path);
        if (count < 0) {
            System.Console.WriteLine("ls: directory read failed (status):");
            System.Console.WriteLine(System.Australis.Files.Status());
            return System.Australis.Files.Status();
        }
        int index = 0;
        while (index < count) {
            int length = System.Australis.Files.DirectoryName(path, index);
            if (length < 0) {
                System.Console.WriteLine("ls: directory entry failed (status):");
                System.Console.WriteLine(System.Australis.Files.Status());
                return System.Australis.Files.Status();
            }
            if (length > 0) {
                System.Australis.Files.WriteResult();
                System.Console.WriteLine();
            }
            index = index + 1;
        }
        return 0;
    }
}
