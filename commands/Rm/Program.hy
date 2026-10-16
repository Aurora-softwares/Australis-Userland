public class Program {
    public static int Main(string[] args) {
        if (args.Length != 1) {
            System.Console.WriteLine("Usage: rm <file-or-empty-directory>"); return 2;
        }
        int kind = System.Australis.Files.StatKind(args[0]);
        if (kind < 0) {
            int missing = System.Australis.Files.Status();
            System.Console.Write("rm: stat failed (status ");
            System.Console.Write(missing); System.Console.WriteLine(")");
            return missing;
        }
        int status = 1;
        if (kind == 1) { status = System.Australis.Files.Delete(args[0]); }
        else if (kind == 2) { status = System.Australis.Files.Rmdir(args[0]); }
        if (status != 0) {
            System.Console.Write("rm: remove failed (status ");
            System.Console.Write(status); System.Console.WriteLine(")");
        }
        return status;
    }
}
