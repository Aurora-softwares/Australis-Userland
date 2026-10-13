public class Program {
    public static int Main(string[] args) {
        if (args.Length != 0) {
            System.Console.WriteLine("Usage: ps");
            return 2;
        }
        int api = System.Australis.SystemInfo.Query(0);
        if (api < 3) {
            System.Console.WriteLine("ps: system information API 3 is required");
            return 3;
        }
        System.Console.WriteLine("PID STATE");
        int active = System.Australis.SystemInfo.Query(40);
        if (active > 0) {
            System.Console.Write(active);
            System.Console.WriteLine(" running (foreground)");
        }
        int previous = System.Australis.SystemInfo.Query(41);
        int state = System.Australis.SystemInfo.Query(42);
        if (previous > 0) {
            System.Console.Write(previous);
            if (state == 2) {
                System.Console.Write(" exited, status ");
                System.Console.WriteLine(System.Australis.SystemInfo.Query(43));
            } else if (state == 3) {
                System.Console.Write(" faulted, reason ");
                System.Console.WriteLine(System.Australis.SystemInfo.Query(44));
            } else { System.Console.WriteLine(" unknown"); }
        }
        System.Console.Write("program launches: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(45));
        return 0;
    }
}
