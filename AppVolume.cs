using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

public static class AppVolume
{
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] private class DeviceEnumerator { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IDevices {
        void EnumAudioEndpoints(int flow, uint state, out IntPtr devices);
        void GetDefaultAudioEndpoint(int flow, int role, out IDevice device);
    }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IDevice {
        void Activate(ref Guid iid, uint context, IntPtr parameters, [MarshalAs(UnmanagedType.IUnknown)] out object result);
    }
    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IManager {
        void GetAudioSessionControl(IntPtr guid, uint flags, out IntPtr control);
        void GetSimpleAudioVolume(IntPtr guid, uint flags, out IntPtr volume);
        void GetSessionEnumerator(out ISessions sessions);
    }
    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISessions {
        void GetCount(out int count);
        void GetSession(int index, [MarshalAs(UnmanagedType.IUnknown)] out object control);
    }
    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IControl {
        void GetState(out int state);
        void GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
        void SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string name, IntPtr context);
        void GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string path);
        void SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string path, IntPtr context);
        void GetGroupingParam(out Guid group);
        void SetGroupingParam(ref Guid group, IntPtr context);
        void RegisterAudioSessionNotification(IntPtr client);
        void UnregisterAudioSessionNotification(IntPtr client);
        void GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
        void GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
        void GetProcessId(out uint id);
    }
    [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IVolume {
        void SetMasterVolume(float level, ref Guid context);
        void GetMasterVolume(out float level);
        void SetMute([MarshalAs(UnmanagedType.Bool)] bool muted, ref Guid context);
        void GetMute([MarshalAs(UnmanagedType.Bool)] out bool muted);
    }

    public static string ProcessName(string source) {
        return !String.IsNullOrEmpty(source) && source.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
            ? Path.GetFileNameWithoutExtension(source) : null;
    }
    public static double Read(string source) { return Access(source, null); }
    public static double Set(string source, double percent) {
        if (Double.IsNaN(percent) || Double.IsInfinity(percent) || percent < 0 || percent > 100)
            throw new ArgumentOutOfRangeException("percent");
        return Access(source, percent);
    }
    private static double Access(string source, double? percent) {
        string name = ProcessName(source);
        if (name == null) return -1;
        object enumerator = new DeviceEnumerator();
        IDevice device = null;
        object manager = null;
        ISessions sessions = null;
        try {
            // shortcut: control sessions on the default multimedia output; extend for per-app output routing when needed.
            ((IDevices)enumerator).GetDefaultAudioEndpoint(0, 1, out device);
            var iid = typeof(IManager).GUID;
            device.Activate(ref iid, 23, IntPtr.Zero, out manager);
            ((IManager)manager).GetSessionEnumerator(out sessions);
            int count;
            sessions.GetCount(out count);
            double result = -1;
            for (int i = 0; i < count; i++) {
                object control;
                sessions.GetSession(i, out control);
                try {
                    uint pid;
                    ((IControl)control).GetProcessId(out pid);
                    string processName;
                    try { using (var process = Process.GetProcessById((int)pid)) processName = process.ProcessName; }
                    catch (ArgumentException) { continue; }
                    if (!String.Equals(name, processName, StringComparison.OrdinalIgnoreCase)) continue;
                    var volume = (IVolume)control;
                    var context = Guid.Empty;
                    if (percent.HasValue) {
                        volume.SetMasterVolume((float)(percent.Value / 100), ref context);
                        volume.SetMute(percent.Value == 0, ref context);
                    }
                    float level;
                    bool muted;
                    volume.GetMasterVolume(out level);
                    volume.GetMute(out muted);
                    result = muted ? 0 : Math.Round(level * 100);
                } finally { Marshal.ReleaseComObject(control); }
            }
            return result;
        } finally {
            if (sessions != null) Marshal.ReleaseComObject(sessions);
            if (manager != null) Marshal.ReleaseComObject(manager);
            if (device != null) Marshal.ReleaseComObject(device);
            Marshal.ReleaseComObject(enumerator);
        }
    }
}
