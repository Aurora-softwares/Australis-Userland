public class Program {
    private static int Exchange(int channel, byte[] request,
        byte[] reply, int expectedStatus) {
        if (System.Australis.Channel.Send(channel, 2, request) != 0) { return -1; }
        int rounds = 0;
        while (rounds < 1000) {
            int received = System.Australis.Channel.Receive(channel, reply);
            if (received == 2) {
                if (reply[0] == request[0] && reply[1] == expectedStatus) {
                    return 0;
                }
                return -2;
            }
            int slept = System.Australis.Process.Sleep(1);
            rounds = rounds + 1;
        }
        return -3;
    }

    public static int Main(string[] args) {
        byte[] mouse = new byte[3];
        if (System.Australis.Display.Acquire() != -13 ||
            System.Australis.Display.SetMode(640, 480) != -13 ||
            System.Australis.Display.PollMouse(mouse) != -13 ||
            System.Australis.Display.CaptureKeyboard(1) != -13 ||
            System.Australis.Display.PollKey() != -13) { return 3; }
        int channel = -1; int rounds = 0;
        while (channel < 1 && rounds < 1000) {
            channel = System.Australis.Channel.Accept(2);
            if (channel < 1) { int slept = System.Australis.Process.Sleep(1); }
            rounds = rounds + 1;
        }
        if (channel < 1) { return 1; }
        // Async input can arrive before a two-byte reply; receive the full
        // protocol frame so it cannot block the channel head.
        byte[] reply = new byte[7];
        byte[] create = new byte[4];
        create[0] = 1; create[1] = 42; create[2] = 104; create[3] = 217;
        if (Exchange(channel, create, reply, 2) != 0) { return 2; }
        byte[] cell = new byte[7];
        cell[0] = 2; cell[1] = 1; cell[2] = 1; cell[3] = 1;
        cell[4] = 112; cell[5] = 205; cell[6] = 249;
        if (Exchange(channel, cell, reply, 0) != 0) { return 4; }
        cell[1] = 2;
        if (Exchange(channel, cell, reply, 1) != 0) { return 5; }
        byte[] close = new byte[2];
        close[0] = 3; close[1] = 2;
        if (Exchange(channel, close, reply, 1) != 0) { return 6; }
        if (Exchange(channel, cell, reply, 0) != 0) { return 7; }
        if (Exchange(channel, create, reply, 2) != 0) { return 8; }
        if (Exchange(channel, cell, reply, 1) != 0) { return 9; }
        byte[] incoming = new byte[7];
        while (true) {
            int received = System.Australis.Channel.Receive(channel, incoming);
            if (received == 7 && incoming[0] == 4 && incoming[1] == 2 &&
                incoming[2] == 2) {
                System.Console.WriteLine("DisplayDemoB: pointer down");
            }
            if (received == 7 && incoming[0] == 4 && incoming[1] == 2 &&
                incoming[2] == 1) {
                System.Console.WriteLine("DisplayDemoB: pointer move");
            }
            if (received == 7 && incoming[0] == 4 && incoming[1] == 2 &&
                incoming[2] == 3) {
                System.Console.WriteLine("DisplayDemoB: pointer up");
            }
            if (received == 3 && incoming[0] == 5 && incoming[1] == 2) {
                System.Console.WriteLine("DisplayDemoB: key");
                if (incoming[2] == 98) {
                    cell[2] = 0; cell[3] = 0;
                    cell[4] = 240; cell[5] = 211; cell[6] = 62;
                    if (Exchange(channel, cell, reply, 1) != 0) { return 10; }
                }
            }
            int slept = System.Australis.Process.Sleep(10);
            if (slept != 0) { break; }
        }
        return 0;
    }
}
