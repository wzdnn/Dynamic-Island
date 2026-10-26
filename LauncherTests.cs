using System;
using System.IO;
using System.Reflection;

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
            Console.WriteLine("PASS: embedded payload, paths with spaces, preference migration and settings preservation.");
            return 0;
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
}
