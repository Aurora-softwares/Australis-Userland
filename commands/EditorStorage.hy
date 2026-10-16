public class EditorStorage {
    // Return -1 for an I/O error and -2 when the file exceeds the editor buffer.
    public static int Load(string path, byte[] contents, byte[] chunk) {
        int kind = System.Australis.Files.StatKind(path);
        if (kind < 0 && System.Australis.Files.Status() == 4) { return 0; }
        if (kind != 1) { return -1; }
        int input = System.Australis.Files.OpenReadHandle(path);
        if (input < 3) { return -1; }
        int length = 0; int result = 0; bool done = false;
        while (!done) {
            int count = System.Australis.Files.ReadHandle(input, chunk, 128);
            if (count < 0) { result = -1; done = true; }
            else if (count == 0) { done = true; }
            else if (count > contents.Length - length) { result = -2; done = true; }
            else {
                int i = 0;
                while (i < count) {
                    contents[length + i] = chunk[i]; i = i + 1;
                }
                length = length + count;
            }
        }
        if (System.Australis.Files.CloseHandle(input) != 0) { result = -1; }
        if (result != 0) { return result; }
        return length;
    }

    public static int Save(string path, byte[] contents, int length, byte[] chunk) {
        int kind = System.Australis.Files.StatKind(path);
        bool created = false;
        if (kind < 0) {
            if (System.Australis.Files.Status() != 4) {
                return System.Australis.Files.Status();
            }
            int createStatus = System.Australis.Files.Create(path, "");
            if (createStatus != 0) { return createStatus; }
            created = true;
        } else if (kind != 1) { return 1; }
        int output = System.Australis.Files.OpenWriteHandle(path);
        if (output < 3) {
            int openStatus = System.Australis.Files.Status();
            if (created) { System.Australis.Files.Delete(path); }
            return openStatus;
        }
        int result = System.Australis.Files.TruncateHandle(output, 0);
        int offset = 0;
        while (result == 0 && offset < length) {
            int count = length - offset;
            if (count > 128) { count = 128; }
            int i = 0;
            while (i < count) {
                chunk[i] = contents[offset + i]; i = i + 1;
            }
            result = System.Australis.Files.WriteHandle(output, chunk, count);
            offset = offset + count;
        }
        int closed = System.Australis.Files.CloseHandle(output);
        if (result == 0 && closed != 0) { result = closed; }
        if (result != 0 && created) { System.Australis.Files.Delete(path); }
        return result;
    }
}
