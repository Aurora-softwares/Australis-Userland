public class Program {
    public static int Main(string[] args) {
        if (args.Length != 2) {
            System.Console.WriteLine("Usage: mv <source> <destination>"); return 2;
        }
        if (args[0] == args[1]) { return 0; }
        int status = System.Australis.Files.Rename(args[0], args[1]);
        if (status == 13) {
            status = CopyCore.Copy(args[0], args[1]);
            if (status == 0) { status = System.Australis.Files.Delete(args[0]); }
        }
        if (status != 0) {
            System.Console.Write("mv: failed (status ");
            System.Console.Write(status); System.Console.WriteLine(")");
        }
        return status;
    }
}
