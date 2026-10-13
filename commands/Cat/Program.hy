public class Program {
    public static int Main(string[] args) {
        if (args.Length != 1) {
            System.Console.WriteLine("Usage: cat <path>");
            return 2;
        }
        if (System.Australis.Files.ApiVersion() != 1) {
            System.Console.WriteLine("cat: unsupported file API");
            return 3;
        }

        int opened = System.Australis.Files.OpenRead(args[0]);
        if (opened != 0) {
            System.Console.WriteLine("cat: open failed (status):");
            System.Console.WriteLine(opened);
            return opened;
        }

        int failure = 0;
        bool done = false;
        while (!done) {
            int count = System.Australis.Files.ReadChecked(128);
            if (count < 0) {
                failure = System.Australis.Files.Status();
                System.Console.WriteLine("cat: read failed (status):");
                System.Console.WriteLine(failure);
                done = true;
            } else if (count == 0) {
                done = true;
            } else {
                System.Australis.Files.WriteResult();
            }
        }

        int closed = System.Australis.Files.CloseChecked();
        if (failure == 0 && closed != 0) {
            System.Console.WriteLine("cat: close failed (status):");
            System.Console.WriteLine(closed);
            failure = closed;
        }
        return failure;
    }
}
