public class Program {
    public static int Main(string[] args) {
        if (args.Length != 0) {
            System.Console.WriteLine("Usage: drivers");
            return 2;
        }
        if (System.Australis.SystemInfo.Query(0) < 4) {
            System.Console.WriteLine("drivers: system information API 4 is required");
            return 3;
        }
        System.Console.WriteLine("Active kernel drivers:");
        int serial = System.Australis.SystemInfo.Query(48);
        if (serial % 2 == 1) { System.Console.WriteLine("serial: COM1 ready"); }
        else { System.Console.WriteLine("serial: unavailable"); }
        int storage = System.Australis.SystemInfo.Query(49);
        if (storage == 1) { System.Console.Write("storage: AHCI"); }
        else if (storage == 2) { System.Console.Write("storage: NVMe"); }
        else { System.Console.WriteLine("storage: unavailable"); }
        if (storage == 1 || storage == 2) {
            int irq = System.Australis.SystemInfo.Query(50);
            if (irq == 1) { System.Console.WriteLine(" (MSI)"); }
            else if (irq == 2) { System.Console.WriteLine(" (MSI-X)"); }
            else { System.Console.WriteLine(" (interrupt unavailable)"); }
        }
        int usb = System.Australis.SystemInfo.Query(51);
        if (usb == 10) { System.Console.WriteLine("usb: xHCI keyboard ready"); }
        else if (usb == 20) { System.Console.WriteLine("usb: xHCI storage ready"); }
        else if (System.Australis.SystemInfo.Query(53) == 1) {
            System.Console.WriteLine("usb: xHCI initialized, no ready device");
        } else { System.Console.WriteLine("usb: unavailable"); }
        int clock = System.Australis.SystemInfo.Query(25);
        if (clock == 1) { System.Console.WriteLine("timer: calibrated"); }
        else { System.Console.WriteLine("timer: unavailable"); }
        return 0;
    }
}
