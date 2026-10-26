using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Dynamic Island")]
[assembly: AssemblyVersion("1.3.0.0")]

internal static class Launcher
{
    internal static readonly string[] PayloadFiles = { "Island.ps1", "Media.ps1", "Notifications.ps1", "MediaReader.cs", "AppVolume.cs", "WhatsAppCalls.cs" };

    internal static void ExtractPayload(string folder)
    {
        Directory.CreateDirectory(folder);
        foreach (string file in PayloadFiles)
            using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream(file))
            {
                if (resource == null) throw new InvalidDataException("File internal tidak ditemukan: " + file);
                using (Stream output = File.Create(Path.Combine(folder, file))) resource.CopyTo(output);
            }
    }

    internal static void MigrateSettings(string oldPath, string settingsPath)
    {
        if (!File.Exists(settingsPath) && File.Exists(oldPath))
        {
            try { File.Copy(oldPath, settingsPath, false); }
            catch (IOException) { if (!File.Exists(settingsPath)) throw; }
        }
    }

    [STAThread]
    private static int Main(string[] args)
    {
        string folder = null;
        try
        {
            bool selfTest = args.Length == 1 && args[0] == "--self-test";
            if (args.Length != 0 && !selfTest) throw new ArgumentException("Argumen tidak dikenal.");
            string dataFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DynamicIsland");
            folder = Path.Combine(dataFolder, "runtime", Guid.NewGuid().ToString("N"));
            ExtractPayload(folder);
            string settingsPath = Path.Combine(dataFolder, "settings.local.json");
            if (!selfTest) MigrateSettings(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "settings.local.json"), settingsPath);
            var start = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + Path.Combine(folder, "Island.ps1") + "\" -SettingsPath \"" + settingsPath + "\"" + (selfTest ? " -SelfTest" : ""),
                WorkingDirectory = folder,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            using (Process process = Process.Start(start))
            {
                process.WaitForExit();
                if (process.ExitCode != 0 && !selfTest)
                    MessageBox.Show("Dynamic Island berhenti karena kesalahan. Jalankan pemeriksaan SelfTest dari README untuk diagnosis.", "Dynamic Island");
                return process.ExitCode;
            }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "Dynamic Island", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            // Only remove this launch's private payload after its PowerShell process exits.
            if (folder != null && Directory.Exists(folder))
            {
                try { Directory.Delete(folder, true); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }
    }
}
