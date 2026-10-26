using System;
using System.IO;
using System.Reflection;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

internal static class LauncherTests
{
    private static void Check(bool condition, string message)
    {
        if (!condition) throw new Exception(message);
    }

    private static int Main(string[] args)
    {
        string root = Path.Combine(args[0], "launcher-test-" + Guid.NewGuid().ToString("N"));
        try
        {
            string payload = Path.Combine(root, "runtime with spaces");
            Launcher.ExtractPayload(payload);
            Check(Directory.GetFiles(payload).Length == Launcher.PayloadFiles.Length, "Unexpected payload files");
            foreach (string file in Launcher.PayloadFiles)
                using (var resource = new StreamReader(Assembly.GetExecutingAssembly().GetManifestResourceStream(file)))
                    Check(File.ReadAllText(Path.Combine(payload, file)) == resource.ReadToEnd(), "Payload differs: " + file);
            string oldPath = Path.Combine(root, "old-settings.json");
            string newPath = Path.Combine(root, "settings.local.json");
            Launcher.MigrateSettings(oldPath, newPath);
            Check(!File.Exists(newPath), "Missing legacy settings created a file");
            File.WriteAllText(oldPath, "{\"AlwaysOnTop\":false}");
            Launcher.MigrateSettings(oldPath, newPath);
            Check(File.ReadAllText(newPath) == File.ReadAllText(oldPath), "Disabled preference was not migrated");
            File.WriteAllText(oldPath, "{\"AlwaysOnTop\":true}");
            Launcher.MigrateSettings(oldPath, newPath);
            Check(File.ReadAllText(newPath) == "{\"AlwaysOnTop\":false}", "Existing preference was overwritten");
            Directory.Delete(payload, true);
            Check(File.Exists(newPath), "Payload cleanup removed settings");
            foreach (string invalid in new[] { "{}", "null", "{\"kind\":\"shell\"}", "{\"kind\":\"ping\",\"extra\":true}", "{\"kind\":\"message\",\"title\":5,\"body\":\"x\"}", "{\"kind\":\"message\",\"title\":\"x\",\"body\":null}" })
            {
                bool rejected = false;
                try { WebBridge.Parse(invalid); } catch { rejected = true; }
                Check(rejected, "Unsafe native message accepted");
            }
            using (var frame = new MemoryStream())
            {
                WebBridge.WriteFrame(frame, "{\"kind\":\"ping\"}");
                frame.Position = 0;
                Check(WebBridge.ReadFrame(frame) == "{\"kind\":\"ping\"}", "Framing failed");
            }
            foreach (int size in new[] { -1, 0, 8193 })
            {
                bool rejected = false;
                try { WebBridge.ReadFrame(new MemoryStream(BitConverter.GetBytes(size))); } catch (InvalidDataException) { rejected = true; }
                Check(rejected, "Invalid frame length accepted");
            }
            using (var bridge = new WebBridge())
            {
                Check(WebBridge.Forward("{\"kind\":\"ping\"}") == "{\"ok\":true}", "Pipe ping failed");
                Check(bridge.TakeLatest() == null, "Ping displayed a notice");
                string notice = "{\"kind\":\"call\",\"title\":\"Synthetic only\",\"body\":\"Test\"}";
                WebBridge.Forward(notice);
                Check(bridge.TakeLatest().Kind == "call", "Call forwarding failed");
                WebBridge.Forward(notice);
                Check(bridge.TakeLatest() == null, "Duplicate notice not suppressed");
                var start = new ProcessStartInfo(args[1], WebBridge.ExtensionOrigin) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
                using (var host = Process.Start(start))
                {
                    WebBridge.WriteFrame(host.StandardInput.BaseStream, "{\"kind\":\"message\",\"title\":\"Native host test\",\"body\":\"Synthetic only\"}");
                    var response = Task.Factory.StartNew(() => WebBridge.ReadFrame(host.StandardOutput.BaseStream));
                    Check(response.Wait(5000) && response.Result == "{\"ok\":true}", "Native EXE stdio failed");
                    Check(host.WaitForExit(5000) && host.ExitCode == 0, "Native host did not exit");
                    Check(bridge.TakeLatest().Title == "Native host test", "Native EXE did not forward");
                }
            }
            Check(WebBridge.RunHost("chrome-extension://untrusted/") == 1, "Untrusted extension origin accepted");
            Console.WriteLine("PASS: native framing, validation, pipe forwarding, duplicate suppression, EXE stdio and origin restriction.");
            Console.WriteLine("PASS: embedded payload, paths with spaces, preference migration and settings preservation.");
            return 0;
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
}
