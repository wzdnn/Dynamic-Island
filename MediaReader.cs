using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class MediaReader {
    [DllImport("shcore.dll", PreserveSig = false)]
    private static extern void CreateStreamOverRandomAccessStream([MarshalAs(UnmanagedType.IUnknown)] object source, ref Guid iid, out IStream stream);
    public static byte[] ReadCover(object source) {
        IStream stream = null;
        IntPtr count = Marshal.AllocHGlobal(4);
        try {
            var iid = typeof(IStream).GUID;
            CreateStreamOverRandomAccessStream(source, ref iid, out stream);
            System.Runtime.InteropServices.ComTypes.STATSTG stat;
            stream.Stat(out stat, 1);
            if (stat.cbSize <= 0 || stat.cbSize > 5 * 1024 * 1024) return null;
            using (var result = new MemoryStream()) {
                var chunk = new byte[8192];
                long remaining = stat.cbSize;
                while (remaining > 0) {
                    int requested = (int)Math.Min(chunk.Length, remaining);
                    stream.Read(chunk, requested, count);
                    int read = Marshal.ReadInt32(count);
                    if (read <= 0 || read > requested) throw new IOException("Incomplete cover stream");
                    result.Write(chunk, 0, read);
                    remaining -= read;
                }
                return result.ToArray();
            }
        } finally {
            Marshal.FreeHGlobal(count);
            if (stream != null) Marshal.ReleaseComObject(stream);
        }
    }
}
