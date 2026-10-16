public class Program {
    public static int Main(string[] args) {
        if (args.Length != 1) {
            System.Console.WriteLine("Usage: mkdir <directory>"); return 2;
        }
        int status = System.Australis.Files.Mkdir(args[0]);
        if (status != 0) {
            System.Console.Write("mkdir: failed (status ");
            System.Console.Write(status); System.Console.WriteLine(")");
        }
        return status;
    }
}
