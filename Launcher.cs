using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Dynamic Island")]
[assembly: AssemblyVersion("1.2.0.0")]

internal static class Launcher
{
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            bool selfTest = args.Length == 1 && args[0] == "--self-test";
            if (args.Length != 0 && !selfTest) throw new ArgumentException("Argumen tidak dikenal.");
            string folder = AppDomain.CurrentDomain.BaseDirectory;
            foreach (string file in new[] { "Island.ps1", "Media.ps1", "Notifications.ps1", "MediaReader.cs", "AppVolume.cs", "WhatsAppCalls.cs" })
                if (!File.Exists(Path.Combine(folder, file)))
                    throw new FileNotFoundException("Ekstrak seluruh isi ZIP sebelum menjalankan aplikasi. File tidak ditemukan: " + file);
            var start = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + Path.Combine(folder, "Island.ps1") + "\"" + (selfTest ? " -SelfTest" : ""),
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
    }
}
