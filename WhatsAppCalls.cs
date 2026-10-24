using System;
using System.Text;
using System.Runtime.InteropServices;

public static class WhatsAppCalls
{
    private delegate bool EnumWindow(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindow callback, IntPtr data);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("kernel32.dll")] private static extern IntPtr OpenProcess(uint access, bool inherit, uint id);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern int GetPackageFamilyName(IntPtr process, ref uint length, StringBuilder name);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr window, int command);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);

    public static bool Matches(string title, string package)
    {
        // shortcut: window titles cannot distinguish ringing from connected calls; use a call-state API when available.
        return package == "5319275A.WhatsAppDesktop_cv1g1gvanyjgm" &&
            (title == "Voice call" || title == "Video call" || title == "Panggilan suara" || title == "Panggilan video");
    }

    private static bool IsCallWindow(IntPtr window)
    {
        if (!IsWindowVisible(window)) return false;
        var title = new StringBuilder(256);
        GetWindowText(window, title, title.Capacity);
        if (!Matches(title.ToString(), "5319275A.WhatsAppDesktop_cv1g1gvanyjgm")) return false;
        uint id;
        GetWindowThreadProcessId(window, out id);
        var process = OpenProcess(0x1000, false, id);
        if (process == IntPtr.Zero) return false;
        try {
            uint length = 256;
            var package = new StringBuilder((int)length);
            return GetPackageFamilyName(process, ref length, package) == 0 && Matches(title.ToString(), package.ToString());
        } finally { CloseHandle(process); }
    }

    public static IntPtr Find()
    {
        var result = IntPtr.Zero;
        if (!EnumWindows(delegate(IntPtr window, IntPtr data) {
            if (!IsCallWindow(window)) return true;
            result = window;
            return false;
        }, IntPtr.Zero) && result == IntPtr.Zero) throw new InvalidOperationException("Cannot enumerate call windows.");
        return result;
    }

    public static bool Open(IntPtr window)
    {
        if (!IsCallWindow(window)) return false;
        if (IsIconic(window)) ShowWindowAsync(window, 9);
        return SetForegroundWindow(window);
    }
}
