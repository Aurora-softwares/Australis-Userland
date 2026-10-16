public class Program {
    public static int Main(string[] args) {
        if (args.Length != 2) {
            System.Console.WriteLine("Usage: cp <source> <destination>"); return 2;
        }
        return CopyCore.Copy(args[0], args[1]);
    }
}
