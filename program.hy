public class Program {
    private static int LoadManifest(byte[] bytes) {
        int handle = System.Australis.Files.OpenReadHandle(
            "/System/Config/startup.manifest");
        if (handle < 3) { return -1; }
        int length = System.Australis.Files.ReadHandle(handle, bytes, 256);
        byte[] extra = new byte[1];
        int trailing = System.Australis.Files.ReadHandle(handle, extra, 1);
        int closed = System.Australis.Files.CloseHandle(handle);
        if (length < 12 || trailing != 0 || closed != 0 ||
            bytes[0] != 65 || bytes[1] != 85 || bytes[2] != 83 ||
            bytes[3] != 77 || bytes[4] != 49 || bytes[5] != 10) { return -1; }
        return length;
    }

    // AUSM1 has bounded, ordered records: name|absolute path|retries|ready rounds|mode.
    // O is a one-shot readiness check; S is the final interactive session.
    private static int ParseRecord(byte[] bytes, int length, int start, byte[] fields) {
        int cursor = start; int nameStart = cursor;
        while (cursor < length && bytes[cursor] != 124) {
            int c = bytes[cursor];
            if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122))) { return -1; }
            cursor = cursor + 1;
        }
        int nameLength = cursor - nameStart;
        if (nameLength < 1 || nameLength > 31 || cursor >= length) { return -1; }
        fields[0] = (byte)nameStart; fields[1] = (byte)nameLength;
        cursor = cursor + 1;
        int pathStart = cursor;
        while (cursor < length && bytes[cursor] != 124) {
            int c = bytes[cursor];
            if (c < 33 || c > 126) { return -1; }
            cursor = cursor + 1;
        }
        int pathLength = cursor - pathStart;
        if (pathLength < 2 || pathLength > 255 || bytes[pathStart] != 47 ||
            cursor >= length || cursor + 5 >= length) { return -1; }
        fields[2] = (byte)pathStart; fields[3] = (byte)pathLength;
        cursor = cursor + 1;
        int retries = bytes[cursor] - 48; cursor = cursor + 1;
        if (retries < 1 || retries > 5 || bytes[cursor] != 124) { return -1; }
        fields[4] = (byte)retries;
        cursor = cursor + 1;
        int readyRounds = 0; int digits = 0;
        while (cursor < length && bytes[cursor] >= 48 && bytes[cursor] <= 57 &&
            digits < 5) {
            readyRounds = readyRounds * 10 + bytes[cursor] - 48;
            digits = digits + 1; cursor = cursor + 1;
        }
        if (digits < 1 || readyRounds < 1 || readyRounds > 60000 ||
            cursor + 2 >= length || bytes[cursor] != 124 ||
            (bytes[cursor + 1] != 79 && bytes[cursor + 1] != 83) ||
            bytes[cursor + 2] != 10) { return -1; }
        fields[5] = (byte)(readyRounds % 256);
        fields[6] = (byte)(readyRounds / 256);
        fields[7] = bytes[cursor + 1];
        return cursor + 3;
    }

    private static string Slice(byte[] source, int start, int length) {
        byte[] bytes = new byte[256];
        int i = 0;
        while (i < length) {
            bytes[i] = source[start + i]; i = i + 1;
        }
        return System.Australis.Text.FromBytes(bytes, length);
    }

    private static int RunService(string name, string path, int restartLimit,
        int readyRounds) {
        int failures = 0;
        while (failures < restartLimit) {
            int pid = System.Australis.Process.Spawn(path);
            int status = pid; int ready = -4;
            if (pid > 0) {
                ready = System.Australis.Process.WaitReady(pid, readyRounds);
                if (ready == -2) {
                    System.Console.Write("System: service=");
                    System.Console.Write(name);
                    System.Console.WriteLine(" readiness timeout");
                    int terminated = System.Australis.Process.Terminate(pid);
                    int reaped = System.Australis.Process.Wait(pid);
                    status = -2;
                } else {
                    if (ready == 0) {
                        System.Console.Write("System: service=");
                        System.Console.Write(name);
                        System.Console.Write(" ready pid=");
                        System.Console.WriteLine(pid);
                    }
                    status = System.Australis.Process.Wait(pid);
                    if (ready == 0 && status == 0) { return 0; }
                    if (ready != 0 && status == 0) { status = -1; }
                }
            }
            failures = failures + 1;
            System.Console.Write("System: service=");
            System.Console.Write(name);
            System.Console.Write(" attempt=");
            System.Console.Write(failures);
            System.Console.Write(" status=");
            System.Console.Write(status);
            System.Console.Write(" ready=");
            System.Console.WriteLine(ready);
        }
        System.Console.Write("System: ");
        System.Console.Write(name);
        System.Console.WriteLine(" restart limit reached");
        return 1;
    }

    private static int StartDisplay() {
        int pid = System.Australis.Process.Spawn("/System/Core/Display.exec");
        if (pid < 1) {
            System.Console.WriteLine("System: display unavailable");
            return 0;
        }
        // The first composed frame can take many scheduler quanta on a
        // framebuffer backend. Keep supervision bounded, but give it the
        // maximum supported instruction-round budget before terminating it.
        int ready = System.Australis.Process.WaitReady(pid, 100000);
        if (ready != 0) {
            System.Console.Write("System: display readiness failed: ");
            System.Console.WriteLine(ready);
            int terminated = System.Australis.Process.Terminate(pid);
            int reaped = System.Australis.Process.Wait(pid);
            System.Console.WriteLine("System: display unavailable");
            return 0;
        }
        System.Console.WriteLine("System: display ready");
        return pid;
    }

    public static int Main(string[] args) {
        byte[] manifest = new byte[256];
        int length = LoadManifest(manifest);
        if (length < 1) {
            System.Console.WriteLine("System: invalid startup manifest");
            return 1;
        }
        byte[] fields = new byte[8];
        int cursor = 6; int serviceCount = 0; int sessionCount = 0;
        while (cursor < length && serviceCount < 4) {
            int next = ParseRecord(manifest, length, cursor, fields);
            if (next < 0 || (fields[7] == 83 && next != length)) {
                System.Console.WriteLine("System: invalid startup manifest");
                return 1;
            }
            if (fields[7] == 83) { sessionCount = sessionCount + 1; }
            cursor = next; serviceCount = serviceCount + 1;
        }
        if (cursor != length || sessionCount != 1) {
            System.Console.WriteLine("System: invalid startup manifest");
            return 1;
        }
        cursor = 6;
        while (cursor < length) {
            int next = ParseRecord(manifest, length, cursor, fields);
            string name = Slice(manifest, fields[0], fields[1]);
            string path = Slice(manifest, fields[2], fields[3]);
            int readyRounds = fields[5] + fields[6] * 256;
            int displayPid = 0;
            if (fields[7] == 83) { displayPid = StartDisplay(); }
            int result = RunService(name, path, fields[4], readyRounds);
            if (displayPid > 0) {
                int terminated = System.Australis.Process.Terminate(displayPid);
                int reaped = System.Australis.Process.Wait(displayPid);
                if (terminated != 0 && reaped < 0) {
                    System.Console.Write("System: display exit status=");
                    System.Console.WriteLine(reaped);
                }
            }
            if (result != 0) { return result; }
            if (fields[7] == 83) { return 0; }
            cursor = next;
        }
        System.Console.WriteLine("System: invalid startup manifest");
        return 1;
    }
}
