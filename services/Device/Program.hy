public class Program {
    public static int Main(string[] args) {
        if (System.Australis.SystemInfo.Query(48) < 1) { return 1; }
        int ready = System.Australis.Process.Ready();
        if (ready != 0) { return 2; }
        return 0;
    }
}
