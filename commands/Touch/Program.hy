public class Program {
    public static int Main(string[] args) {
        if (args.Length != 1) {
            System.Console.WriteLine("Usage: touch <file>"); return 2;
        }
        int kind = System.Australis.Files.StatKind(args[0]);
        if (kind == 1) { return 0; }
        if (kind == 2) {
            System.Console.WriteLine("touch: target is a directory"); return 2;
        }
        int status = System.Australis.Files.Status();
        if (status != 4) {
            System.Console.Write("touch: stat failed (status ");
            System.Console.Write(status); System.Console.WriteLine(")");
            return status;
        }
        status = System.Australis.Files.Create(args[0], "");
        if (status != 0) {
            System.Console.Write("touch: create failed (status ");
            System.Console.Write(status); System.Console.WriteLine(")");
        }
        return status;
    }
}
