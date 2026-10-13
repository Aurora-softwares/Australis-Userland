public class Program {
    public static int Main(string[] args) {
        if (args.Length != 0) {
            System.Console.WriteLine("Usage: mem");
            return 2;
        }
        if (System.Australis.SystemInfo.Query(0) < 2) {
            System.Console.WriteLine("mem: system information API 2 is required");
            return 3;
        }
        System.Console.WriteLine("Memory usage:");
        System.Console.Write("page size: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(32));
        System.Console.Write("fresh pages: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(33));
        System.Console.Write("recycled pages: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(34));
        System.Console.Write("available pages: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(35));
        System.Console.Write("kernel heap pages committed: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(36));
        System.Console.Write("kernel heap bytes used: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(37));
        System.Console.Write("memory runtime status: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(38));
        System.Console.Write("page table audit status: ");
        System.Console.WriteLine(System.Australis.SystemInfo.Query(39));
        return 0;
    }
}
