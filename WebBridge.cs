using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

public sealed class WebNotice
{
    public string Kind;
    public string Title;
    public string Body;
    public DateTime Received;
}

public sealed class WebBridge : IDisposable
{
    public const string HostName = "com.dynamicisland.whatsapp";
    public const string ExtensionId = "neailjbinkkijmckjofkijnifeopfaaa";
    public const string ExtensionOrigin = "chrome-extension://" + ExtensionId + "/";
    private readonly Queue<WebNotice> pending = new Queue<WebNotice>();
    private volatile bool running = true;
    private readonly Thread worker;
    private readonly string pipeName;
    private string lastKey;
    private DateTime lastReceived;
    public static string PipeName {
        get {
            string name = "DynamicIsland.Web." + WindowsIdentity.GetCurrent().User.Value + "." + Process.GetCurrentProcess().SessionId;
            string testId = Environment.GetEnvironmentVariable("DYNAMIC_ISLAND_TEST_PIPE");
            if (String.IsNullOrEmpty(testId)) return name;
            return name + ".test." + Guid.Parse(testId).ToString("N");
        }
    }

    public WebBridge()
    {
        pipeName = PipeName;
        worker = new Thread(Listen) { IsBackground = true };
        worker.Start();
    }

    public static WebNotice Parse(string json)
    {
        var parser = new JavaScriptSerializer { MaxJsonLength = 8192, RecursionLimit = 4 };
        var data = parser.DeserializeObject(json) as Dictionary<string, object>;
        if (data == null || !data.ContainsKey("kind")) throw new InvalidDataException();
        string kind = data["kind"] as string;
        if (kind == "ping" && data.Count == 1) return null;
        if (data.Count != 3 || (kind != "message" && kind != "call") || !data.ContainsKey("title") || !data.ContainsKey("body")) throw new InvalidDataException();
        string title = data["title"] as string;
        string body = data["body"] as string;
        if (String.IsNullOrWhiteSpace(title) || title.Length > 160 || body == null || body.Length > 1000) throw new InvalidDataException();
        return new WebNotice { Kind = kind, Title = title, Body = body, Received = DateTime.UtcNow };
    }

    public static string ReadFrame(Stream stream)
    {
        byte[] header = ReadBytes(stream, 4);
        int size = BitConverter.ToInt32(header, 0);
        if (size < 1 || size > 8192) throw new InvalidDataException();
        return new UTF8Encoding(false, true).GetString(ReadBytes(stream, size));
    }

    private static byte[] ReadBytes(Stream stream, int count)
    {
        byte[] bytes = new byte[count];
        for (int read = 0; read < count; )
        {
            int length = stream.Read(bytes, read, count - read);
            if (length == 0) throw new EndOfStreamException();
            read += length;
        }
        return bytes;
    }

    public static void WriteFrame(Stream stream, string json)
    {
        byte[] bytes = Encoding.UTF8.GetBytes(json);
        if (bytes.Length > 8192) throw new InvalidDataException();
        stream.Write(BitConverter.GetBytes(bytes.Length), 0, 4);
        stream.Write(bytes, 0, bytes.Length);
        stream.Flush();
    }

    private void Listen()
    {
        var security = new PipeSecurity();
        security.SetAccessRuleProtection(true, false);
        security.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.NetworkSid, null), PipeAccessRights.FullControl, AccessControlType.Deny));
        security.AddAccessRule(new PipeAccessRule(WindowsIdentity.GetCurrent().User, PipeAccessRights.FullControl, AccessControlType.Allow));
        while (running)
        {
            try
            {
                using (var pipe = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous, 8192, 8192, security))
                {
                    var connection = pipe.BeginWaitForConnection(null, null);
                    using (var wait = connection.AsyncWaitHandle)
                    {
                        while (running && !wait.WaitOne(250)) { }
                        if (!running) {
                            // Finish cancellation before disposing the event used by the pending callback.
                            pipe.Dispose();
                            wait.WaitOne();
                            try { pipe.EndWaitForConnection(connection); } catch (ObjectDisposedException) { } catch (IOException) { }
                            return;
                        }
                        pipe.EndWaitForConnection(connection);
                    }
                    var read = Task.Factory.StartNew(() => ReadFrame(pipe));
                    if (!read.Wait(2000)) { read.ContinueWith(t => { var ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted); continue; }
                    WebNotice notice = Parse(read.Result);
                    if (notice != null)
                    {
                        lock (pending)
                        {
                            string key = notice.Kind + "\n" + notice.Title + "\n" + notice.Body;
                            if (key != lastKey || (notice.Received - lastReceived).TotalSeconds > 3)
                            {
                                if (pending.Count == 16) pending.Dequeue();
                                pending.Enqueue(notice);
                                lastKey = key;
                                lastReceived = notice.Received;
                            }
                        }
                    }
                    WriteFrame(pipe, "{\"ok\":true}");
                }
            }
            catch (Exception) { if (running) Thread.Sleep(100); }
        }
    }

    public WebNotice TakeLatest()
    {
        lock (pending)
        {
            WebNotice latest = null;
            while (pending.Count > 0) latest = pending.Dequeue();
            return latest != null && (DateTime.UtcNow - latest.Received).TotalSeconds < 15 ? latest : null;
        }
    }

    public static string Forward(string json)
    {
        Parse(json);
        using (var pipe = new NamedPipeClientStream(".", PipeName, PipeDirection.InOut, PipeOptions.Asynchronous))
        {
            pipe.Connect(1500);
            WriteFrame(pipe, json);
            var read = Task.Factory.StartNew(() => ReadFrame(pipe));
            if (!read.Wait(2500)) { read.ContinueWith(t => { var ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted); throw new TimeoutException(); }
            return read.Result;
        }
    }

    public static int RunHost(string origin)
    {
        if (origin != ExtensionOrigin) return 1;
        using (Stream input = Console.OpenStandardInput())
        using (Stream output = Console.OpenStandardOutput())
        {
            try { WriteFrame(output, Forward(ReadFrame(input))); }
            catch (Exception) { WriteFrame(output, "{\"ok\":false,\"error\":\"Buka Dynamic Island terbaru, lalu coba lagi.\"}"); }
        }
        return 0;
    }

    public void Dispose()
    {
        running = false;
        worker.Join(3000);
        lock (pending) { pending.Clear(); lastKey = null; }
    }
}
