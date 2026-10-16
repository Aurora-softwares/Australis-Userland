public class Program {
    public static int Main(string[] args) {
        int i = 0;
        while (i < args.Length) {
            if (i > 0) { System.Console.Write(" "); }
            System.Console.Write(args[i]);
            i = i + 1;
        }
        System.Console.WriteLine();
        return 0;
    }
}
