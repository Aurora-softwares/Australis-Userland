public class CopyCore {
    public static int Copy(string source, string destination) {
        if (source == destination) {
            System.Console.WriteLine("copy: source and destination are the same");
            return 2;
        }
        int kind = System.Australis.Files.StatKind(source);
        if (kind != 1) {
            System.Console.WriteLine("copy: source must be a readable file");
            return 2;
        }
        int targetKind = System.Australis.Files.StatKind(destination);
        bool created = false;
        if (targetKind == 2) {
            System.Console.WriteLine("copy: destination is a directory");
            return 2;
        }
        if (targetKind < 0) {
            int targetStatus = System.Australis.Files.Status();
            if (targetStatus != 4) { return targetStatus; }
        }
        int input = System.Australis.Files.OpenReadHandle(source);
        if (input < 3) {
            int openStatus = System.Australis.Files.Status();
            System.Console.WriteLine("copy: cannot open source");
            return openStatus;
        }
        if (targetKind < 0) {
            int createStatus = System.Australis.Files.Create(destination, "");
            if (createStatus != 0) {
                System.Australis.Files.CloseHandle(input);
                System.Console.WriteLine("copy: cannot create destination");
                return createStatus;
            }
            created = true;
        }
        int output = System.Australis.Files.OpenWriteHandle(destination);
        if (output < 3) {
            int outputStatus = System.Australis.Files.Status();
            System.Australis.Files.CloseHandle(input);
            if (created) { System.Australis.Files.Delete(destination); }
            System.Console.WriteLine("copy: cannot open destination");
            return outputStatus;
        }
        int failure = System.Australis.Files.TruncateHandle(output, 0);
        byte[] buffer = new byte[128];
        bool done = failure != 0;
        while (!done) {
            int count = System.Australis.Files.ReadHandle(input, buffer, 128);
            if (count < 0) {
                failure = System.Australis.Files.Status(); done = true;
            } else if (count == 0) { done = true; }
            else {
                failure = System.Australis.Files.WriteHandle(output, buffer, count);
                if (failure != 0) { done = true; }
            }
        }
        int outputClose = System.Australis.Files.CloseHandle(output);
        int inputClose = System.Australis.Files.CloseHandle(input);
        if (failure == 0 && outputClose != 0) { failure = outputClose; }
        if (failure == 0 && inputClose != 0) { failure = inputClose; }
        if (failure != 0) {
            if (created) { System.Australis.Files.Delete(destination); }
            System.Console.Write("copy: I/O failed (status ");
            System.Console.Write(failure); System.Console.WriteLine(")");
        }
        return failure;
    }
}
