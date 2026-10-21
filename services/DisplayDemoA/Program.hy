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
        int gpuHandle = System.Australis.Gpu.Create(8, 8);
        if (gpuHandle > 0) {
            if (System.Australis.Gpu.Clear(2, 0) != -13 ||
                System.Australis.Gpu.Blit(gpuHandle, 0, 0) != -13 ||
                System.Australis.Gpu.CopyRegion(gpuHandle, gpuHandle,
                    0, 0, 1, 1, 0, 0) != -13 ||
                System.Australis.Gpu.Clear(gpuHandle, 0xCB3830) != 0 ||
                System.Australis.Gpu.ReadPixel(gpuHandle, 0, 0) <
                    0xCA372F ||
                System.Australis.Gpu.Destroy(gpuHandle) != 0 ||
                System.Australis.Gpu.ReadPixel(gpuHandle, 0, 0) != -13) {
                return 7;
            }
            System.Console.WriteLine("DisplayDemoA: GPU isolation passed");
        } else if (gpuHandle != -19) { return 7; }
        byte[] mouse = new byte[3];
        byte[] stats = new byte[20];
        if (System.Australis.Display.Acquire() != -13 ||
            System.Australis.Display.FillRect(0, 0, 1, 1, 0) != -13 ||
            System.Australis.Display.BeginFrame() != -13 ||
            System.Australis.Display.PresentFrame() != -13 ||
            System.Australis.Display.Stats(stats) != -13 ||
            System.Australis.Display.AllocateBuffer(8, 8, 32, 1) != -13 ||
            System.Australis.Display.BeginBuffer(1) != -13 ||
            System.Australis.Display.FillBufferRect(1, 0, 0, 1, 1, 0) != -13 ||
            System.Australis.Display.SubmitBuffer(1) != -13 ||
            System.Australis.Display.BufferCompletion(1, 1) != -13 ||
            System.Australis.Display.ReleaseBuffer(1, 1) != -13 ||
            System.Australis.Display.DestroyBuffer(1) != -13 ||
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
        create[0] = 1; create[1] = 203; create[2] = 56; create[3] = 48;
        if (Exchange(channel, create, reply, 1) != 0) { return 2; }
        byte[] cell = new byte[7];
        cell[0] = 2; cell[1] = 2; cell[2] = 2; cell[3] = 1;
        cell[4] = 243; cell[5] = 165; cell[6] = 82;
        if (Exchange(channel, cell, reply, 0) != 0) { return 4; }
        cell[1] = 1;
        if (Exchange(channel, cell, reply, 1) != 0) { return 5; }
        byte[] incoming = new byte[7];
        while (true) {
            int received = System.Australis.Channel.Receive(channel, incoming);
            if (received == 7 && incoming[0] == 4 && incoming[1] == 1 &&
                incoming[2] == 2) {
                System.Console.WriteLine("DisplayDemoA: pointer down");
            }
            if (received == 7 && incoming[0] == 4 && incoming[1] == 1 &&
                incoming[2] == 1) {
                System.Console.WriteLine("DisplayDemoA: pointer move");
            }
            if (received == 7 && incoming[0] == 4 && incoming[1] == 1 &&
                incoming[2] == 3) {
                System.Console.WriteLine("DisplayDemoA: pointer up");
            }
            if (received == 3 && incoming[0] == 5 && incoming[1] == 1) {
                System.Console.WriteLine("DisplayDemoA: key");
                if (incoming[2] == 97) {
                    cell[2] = 0; cell[3] = 0;
                    cell[4] = 20; cell[5] = 200; cell[6] = 75;
                    if (Exchange(channel, cell, reply, 1) != 0) { return 6; }
                }
            }
            int slept = System.Australis.Process.Sleep(10);
            if (slept != 0) { break; }
        }
        return 0;
    }
}
