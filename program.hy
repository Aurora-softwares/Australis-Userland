public class Program {
    public static int Main(string[] args) {
        int status = System.Australis.Process.Run("/System/Core/CommandShell.exec");
        if (status < 0) {
            System.Console.WriteLine("System: command shell could not start.");
            return 1;
        }
        return status;
    }
}
