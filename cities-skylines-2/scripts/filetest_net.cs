// filetest_net.cs — managed (.NET) analog of the CS2-on-Wine handle-0 mod-download wall.
// Raw C (filetest.exe) proved Wine's kernel32 returns proper handles. This tests the MANAGED
// path PdxSdk actually uses: P/Invoke CreateFile → print the raw handle → wrap in SafeFileHandle
// → check IsInvalid (the exact thing that throws), THEN a managed FileStream write+read.
//
// Build+run inside the bottle (real MS .NET Framework here; Unity uses Mono — see note):
//   wine csc.exe /nologo /out:filetest_net.exe filetest_net.cs
//   wine filetest_net.exe 'C:\some\base'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

class FileTest {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec,
                                    uint disp, uint flags, IntPtr templ);
    const uint GENERIC_WRITE=0x40000000, GENERIC_READ=0x80000000, CREATE_ALWAYS=2, OPEN_EXISTING=3;

    static void ShowRaw(string label, IntPtr h) {
        long v = h.ToInt64();
        string verdict = v==-1 ? "INVALID_HANDLE_VALUE(-1)" : v==0 ? "*** 0/NULL <-- the bug ***" : "ok";
        var safe = new SafeFileHandle(h, false);
        Console.WriteLine("    {0,-20} = 0x{1:x}  ({2})  {3}   SafeFileHandle.IsInvalid={4}",
                          label, v, v, verdict, safe.IsInvalid);
    }

    static void Main(string[] a) {
        string baseDir = a.Length>0 ? a[0] : Path.Combine(Path.GetTempPath(), "filetest_net");
        string deep = Path.Combine(Path.Combine(baseDir, ".downloading"), "74324_36");
        Directory.CreateDirectory(deep);   // managed recursive create
        string file = Path.Combine(deep, "content.bin");
        Console.WriteLine("== base: {0} ==", baseDir);

        // 1) raw P/Invoke CreateFile for WRITE — print the handle Wine hands the managed runtime
        Console.WriteLine("\n[1] P/Invoke CreateFile WRITE: {0}", file);
        IntPtr hw = CreateFile(file, GENERIC_WRITE, 0, IntPtr.Zero, CREATE_ALWAYS, 0x80, IntPtr.Zero);
        Console.WriteLine("    Marshal.GetLastWin32Error={0}", Marshal.GetLastWin32Error());
        ShowRaw("write handle", hw);
        if (hw.ToInt64()!=-1 && hw.ToInt64()!=0) { CloseHandleWrap(hw); }

        // 2) raw P/Invoke CreateFile for READ
        Console.WriteLine("\n[2] P/Invoke CreateFile READ: {0}", file);
        IntPtr hr = CreateFile(file, GENERIC_READ, 1, IntPtr.Zero, OPEN_EXISTING, 0x80, IntPtr.Zero);
        Console.WriteLine("    Marshal.GetLastWin32Error={0}", Marshal.GetLastWin32Error());
        ShowRaw("read handle", hr);
        if (hr.ToInt64()!=-1 && hr.ToInt64()!=0) { CloseHandleWrap(hr); }

        // 3) fully managed FileStream write + read (what PdxSdk actually does)
        Console.WriteLine("\n[3] managed FileStream write+read: {0}", file);
        try {
            using (var fs = new FileStream(file, FileMode.Create, FileAccess.Write))
                { var b = System.Text.Encoding.ASCII.GetBytes("hello managed\n"); fs.Write(b,0,b.Length); }
            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read)) {
                var buf = new byte[64]; int n = fs.Read(buf,0,buf.Length);
                Console.WriteLine("    OK — wrote+read {0} bytes: \"{1}\"", n,
                                  System.Text.Encoding.ASCII.GetString(buf,0,n).TrimEnd());
            }
        } catch (Exception e) {
            Console.WriteLine("    *** FileStream THREW: {0}: {1} ***", e.GetType().Name, e.Message);
        }
        // 4) EXACT PdxSdk mod-write pattern (from PDX.SDK.dll FileIO disasm):
        //    write = new FileStream(path, Create, Write, FileShare.Write);  read = (Open, Read, FileShare.Read)
        Console.WriteLine("\n[4] PdxSdk-EXACT: FileStream(Create,Write,FileShare.Write) then (Open,Read,FileShare.Read)");
        try {
            using (var fs = new FileStream(file, FileMode.Create, FileAccess.Write, FileShare.Write))
                { var b = System.Text.Encoding.ASCII.GetBytes("pdxsdk pattern\n"); fs.Write(b,0,b.Length); }
            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read)) {
                var buf = new byte[64]; int n = fs.Read(buf,0,buf.Length);
                Console.WriteLine("    OK — {0} bytes via FileShare.Write/Read path", n);
            }
        } catch (Exception e) {
            Console.WriteLine("    *** THREW: {0}: {1} ***", e.GetType().Name, e.Message);
        }

        // 5) DIRECTORY op battery — the REAL PdxSdk failure surface (errno-0 / FindNextFile "IOException: Success").
        //    Mirrors PrepareFolderForPatching (enumerate/clean), the nested .metadata create, the content write, delete.
        Console.WriteLine("\n[5] Directory op battery (errno-0 / FindNextFile suspect):");
        string ddl   = Path.Combine(Path.Combine(baseDir, ".downloading"), "74417_17");
        string dmeta = Path.Combine(ddl, ".metadata");
        Try("Directory.CreateDirectory(nested .metadata)", () => Directory.CreateDirectory(dmeta));
        Try("Directory.Exists(.metadata)",                 () => { var _ = Directory.Exists(dmeta); });
        Try("Directory.GetFiles(empty dir)",               () => { var _ = Directory.GetFiles(ddl); });
        Try("Directory.GetDirectories(dir)",               () => { var _ = Directory.GetDirectories(ddl); });
        Try("Directory.GetFileSystemEntries(dir)",         () => { var _ = Directory.GetFileSystemEntries(ddl); });
        Try("EnumerateFiles + iterate",                    () => { foreach (var f in Directory.EnumerateFiles(ddl)) {} });
        Try("EnumerateFileSystemEntries + iterate",        () => { foreach (var f in Directory.EnumerateFileSystemEntries(ddl)) {} });
        Try("FileStream write into .metadata (DirNotFound site)", () => {
            using (var fs = new FileStream(Path.Combine(dmeta, "thumbnail.png"), FileMode.Create, FileAccess.Write, FileShare.Write)) fs.WriteByte(1); });
        Try("Directory.Delete(recursive)  (the DeleteDirectory failure)", () => Directory.Delete(ddl, true));

        // 6) DECOMPOSE the recursive delete — which primitive actually fails?
        Console.WriteLine("\n[6] recursive-delete decomposition:");
        string d6 = Path.Combine(baseDir, "d6"); string d6s = Path.Combine(d6, "sub");
        try { Directory.CreateDirectory(d6s); File.WriteAllText(Path.Combine(d6s, "f.txt"), "x"); } catch {}
        Try("File.Delete(file in subdir)",          () => File.Delete(Path.Combine(d6s, "f.txt")));
        Try("Directory.Delete(EMPTY subdir, false)", () => Directory.Delete(d6s, false));
        Try("Directory.Delete(EMPTY parent, false)", () => Directory.Delete(d6, false));
        // and the recursive form on a fresh tree with a file still in it:
        string d7 = Path.Combine(baseDir, "d7"); string d7s = Path.Combine(d7, "sub");
        try { Directory.CreateDirectory(d7s); File.WriteAllText(Path.Combine(d7s, "f.txt"), "x"); } catch {}
        Try("Directory.Delete(tree w/ file, RECURSIVE)", () => Directory.Delete(d7, true));

        // 7) FIX CANDIDATE: manual recursion using the working primitives — does it succeed where built-in fails?
        Console.WriteLine("\n[7] fix candidate — MANUAL recursive delete:");
        string d8 = Path.Combine(baseDir, "d8"); string d8s = Path.Combine(d8, "sub");
        try { Directory.CreateDirectory(d8s); File.WriteAllText(Path.Combine(d8s, "f.txt"), "x");
              File.WriteAllText(Path.Combine(d8, "g.txt"), "y"); } catch {}
        Try("ManualDelete(tree w/ subdir+files)", () => ManualDelete(d8));
        Console.WriteLine("    d8 gone? {0}", !Directory.Exists(d8));
        // KEY: does the recursive delete actually SUCCEED (dir gone) despite throwing? (stale-errno hypothesis)
        Console.WriteLine("  -- does it throw-but-succeed? --");
        DelCheck("EMPTY dir",            baseDir, "e1", false);
        DelCheck("nested empty subdir",  baseDir, "e2", true);
        DelCheck("flat dir w/ file",     baseDir, "e3", true);

        // 8) THE hypothesis: does Wine's FindFirstFile choke on the \\?\ extended-length prefix?
        Console.WriteLine("\n[8] FindFirstFileW: plain vs \\\\?\\ extended prefix (the recursive-delete enumerator):");
        string ff = Path.Combine(baseDir, "ffdir"); Directory.CreateDirectory(ff);
        File.WriteAllText(Path.Combine(ff, "a.txt"), "x");
        FindTest("plain    ...\\ffdir\\*",        ff + "\\*");
        FindTest("extended \\\\?\\...\\ffdir\\*", "\\\\?\\" + ff + "\\*");

        // 9) hunt the "IOException: Success" (errno-0) throw — ops PrepareFolderForPatching might use
        Console.WriteLine("\n[9] hunt IOException:Success (Move/CreateExisting/enumerate):");
        string m1=Path.Combine(baseDir,"m1"), m2=Path.Combine(baseDir,"m2");
        try { Directory.CreateDirectory(m1); File.WriteAllText(Path.Combine(m1,"f"),"x"); } catch {}
        Try("Directory.Move(m1 -> m2)",            () => Directory.Move(m1, m2));
        string mm1=Path.Combine(baseDir,"mm1"), mm2=Path.Combine(baseDir,"mm2","sub");
        try { Directory.CreateDirectory(Path.Combine(mm1,".metadata")); File.WriteAllText(Path.Combine(mm1,".metadata","t.png"),"x"); } catch {}
        Try("Directory.Move(dir w/ .metadata)",    () => Directory.Move(mm1, mm2));
        string ex=Path.Combine(baseDir,"ex"); try { Directory.CreateDirectory(ex); } catch {}
        Try("Directory.CreateDirectory(EXISTING)", () => Directory.CreateDirectory(ex));
        Try("File.Delete(nonexistent)",            () => File.Delete(Path.Combine(baseDir,"nope.txt")));
        string en=Path.Combine(baseDir,"en"); try { Directory.CreateDirectory(en); File.WriteAllText(Path.Combine(en,"a"),"1"); } catch {}
        Try("DirectoryInfo.EnumerateFiles+iter",   () => { foreach (var f in new DirectoryInfo(en).EnumerateFiles()) {} });

        // 10) MOVE / FILE.DELETE throw-but-succeed check (mirrors DelCheck): is the op safely NOP-able?
        Console.WriteLine("\n[10] Move/File.Delete — throws but ACTUALLY completes? (safe-to-NOP test):");
        MoveCheck("simple dir move",      baseDir, "mv1", false);
        MoveCheck("nested dir (.metadata)",baseDir, "mv2", true);
        FileDelCheck("File.Delete(existing)",    baseDir, "fd1", true);
        FileDelCheck("File.Delete(nonexistent)", baseDir, "fd2", false);

        // 11) EXACT ClearFolderAndKeepPatchFile sequence (PrepareFolderForPatching's failing op), per-op:
        //     ListDirectories -> ListFiles -> foreach subdir DeleteDirectory(recursive) -> foreach file Delete.
        //     Run against a realistic .downloading\<id> (subdir+files + a loose file), reporting which op throws.
        Console.WriteLine("\n[11] ClearFolderAndKeepPatchFile replica (the PrepareFolderForPatching failure):");
        string dl = Path.Combine(Path.Combine(baseDir, ".downloading"), "74324_36");
        try {
            Directory.CreateDirectory(Path.Combine(dl, "sub"));
            File.WriteAllText(Path.Combine(dl, "sub", "content.bin"), "aaa");
            File.WriteAllText(Path.Combine(dl, "manifest.json"), "{}");
            File.WriteAllText(Path.Combine(dl, ".patch"), "keep");
        } catch (Exception e) { Console.WriteLine("    setup threw: "+e.Message); }
        string[] dirs=null, files=null;
        Try("ListDirectories (Directory.GetDirectories)", () => { dirs = Directory.GetDirectories(dl); });
        Try("ListFiles (Directory.GetFiles)",             () => { files = Directory.GetFiles(dl); });
        if (dirs!=null) foreach (var d in dirs) { string dd=d; Try("  DeleteDirectory(recursive) "+Path.GetFileName(dd), () => Directory.Delete(dd, true)); }
        if (files!=null) foreach (var f in files) { string fx=f; if (Path.GetFileName(fx)==".patch") continue; Try("  File.Delete "+Path.GetFileName(fx), () => File.Delete(fx)); }
        Try("ListFilesRecursive (GetFiles SearchOption.AllDirs)", () => { var _ = Directory.GetFiles(dl, "*", SearchOption.AllDirectories); });
        Try("GetLocalModSize (DirectoryInfo.EnumerateFiles+Length)", () => { long tot=0; foreach (var fi in new DirectoryInfo(dl).EnumerateFiles("*", SearchOption.AllDirectories)) tot+=fi.Length; });

        // 12) THREAD-CONTEXT test: the game runs these on ThreadPool workers (log tags [P01:04]/[P02:02]).
        //     GetLastError/errno is thread-local — does the SAME op that passes on the main thread THROW on a pool thread?
        Console.WriteLine("\n[12] main-thread vs ThreadPool-thread (the P0x:0y workers):");
        System.Action<string> runOps = (tag) => {
            string td = Path.Combine(baseDir, "t_"+tag);
            try { Directory.CreateDirectory(Path.Combine(td,"sub")); File.WriteAllText(Path.Combine(td,"sub","c.bin"),"x"); File.WriteAllText(Path.Combine(td,"m.json"),"{}"); } catch {}
            Try(tag+" GetDirectories", () => { var _=Directory.GetDirectories(td); });
            Try(tag+" GetFiles",       () => { var _=Directory.GetFiles(td); });
            Try(tag+" Delete(recursive)", () => Directory.Delete(td, true));
        };
        runOps("MAIN");
        var done = new System.Threading.ManualResetEvent(false);
        System.Threading.ThreadPool.QueueUserWorkItem(_ => { try { runOps("POOL"); } finally { done.Set(); } });
        done.WaitOne(15000);
        var th = new System.Threading.Thread(() => runOps("NEWTHREAD")); th.Start(); th.Join(15000);
        System.Threading.Tasks.Task.Factory.StartNew(() => runOps("TASK")).Wait(15000);

        // 13) UNTESTED STATES: (a) enumerate/delete a NONEXISTENT dir (Wine Directory.Exists false-positive?),
        //     (b) delete a dir with an OPEN file handle (download stream still holding it → sharing violation).
        Console.WriteLine("\n[13] nonexistent-dir + open-handle states:");
        string nx = Path.Combine(baseDir, "does_not_exist_"+baseDir.Length);
        Console.WriteLine("    Directory.Exists(nonexistent) = {0}", Directory.Exists(nx));
        Try("GetDirectories(nonexistent)", () => { var _=Directory.GetDirectories(nx); });
        Try("GetFiles(nonexistent)",       () => { var _=Directory.GetFiles(nx); });
        Try("Delete(nonexistent, recursive)", () => Directory.Delete(nx, true));
        string od = Path.Combine(baseDir, "openhandle");
        Directory.CreateDirectory(od);
        var openFs = new FileStream(Path.Combine(od, "busy.bin"), FileMode.Create, FileAccess.Write, FileShare.None);
        openFs.WriteByte(1); openFs.Flush();  // file left OPEN (not disposed) — mimics an in-flight download write
        Try("Delete(dir w/ OPEN file, recursive)", () => Directory.Delete(od, true));
        Try("File.Delete(OPEN file)",              () => File.Delete(Path.Combine(od, "busy.bin")));
        Try("GetFiles(dir w/ OPEN file)",          () => { var _=Directory.GetFiles(od); });
        openFs.Dispose();

        // 14) RAW directory-handle open — the EXACT CreateFile CreateDirectoryHandle does.
        //     FILE_LIST_DIRECTORY(1), share=7, OPEN_EXISTING(3), FILE_FLAG_BACKUP_SEMANTICS(0x2000000).
        //     Does Wine ever hand back handle VALUE 0 for a DIRECTORY? (0 => the bug; CoreFX rejects it.)
        Console.WriteLine("\n[14] raw dir-handle open (CreateDirectoryHandle's CreateFile), hunting handle-0:");
        string[] targets = { baseDir, Path.Combine(baseDir, ".downloading"), Path.Combine(Path.Combine(baseDir, ".downloading"), "80095_28") };
        try { Directory.CreateDirectory(targets[2]); } catch {}
        int zeros=0, ok=0, inval=0;
        for (int r=0; r<40; r++) {
            foreach (var dir in targets) {
                IntPtr h = CreateFile(dir, 1, 7, IntPtr.Zero, 3, 0x2000000, IntPtr.Zero);
                long v = h.ToInt64();
                if (v==0) { zeros++; if (zeros<=3) Console.WriteLine("    *** handle==0 (THE BUG) on {0}  err={1}", dir, Marshal.GetLastWin32Error()); }
                else if (v==-1) { inval++; if (inval<=2) Console.WriteLine("    handle==-1 INVALID on {0}  err={1}", dir, Marshal.GetLastWin32Error()); }
                else { ok++; if (r==0) Console.WriteLine("    ok handle=0x{0:x} on {1}", v, Path.GetFileName(dir)); }
                if (v!=0 && v!=-1) CloseHandle(h);
            }
        }
        Console.WriteLine("    == over {0} opens: handle0={1}  invalid(-1)={2}  ok(nonzero)={3} ==", 40*targets.Length, zeros, inval, ok);

        // 15) Did graceful-enum break nested Directory.CreateDirectory? Replicate the download's write pattern:
        //     create a DEEP path where no ancestors exist, verify each level, then FileStream-write into it.
        Console.WriteLine("\n[15] nested CreateDirectory + write (the .metadata / .cpatch DirectoryNotFound site):");
        string deepP = baseDir;
        foreach (var seg in new[]{".downloading","74324_36",".cpatch","a3b6b122",".36","-1_to_36"}) deepP = Path.Combine(deepP, seg);
        Try("CreateDirectory(deep nested, no ancestors)", () => Directory.CreateDirectory(deepP));
        Console.WriteLine("    deepest exists? {0}", Directory.Exists(deepP));
        Try("FileStream write into deepest (manifest)", () => {
            using (var fs = new FileStream(Path.Combine(deepP,"manifest"), FileMode.Create, FileAccess.Write, FileShare.Write)) fs.WriteByte(1);
        });
        string meta = Path.Combine(Path.Combine(Path.Combine(baseDir,".downloading"),"74324_36b"),".metadata");
        Try("CreateDirectory(.metadata parent)", () => Directory.CreateDirectory(meta));
        Try("FileStream write .metadata\\thumbnail.png", () => {
            using (var fs = new FileStream(Path.Combine(meta,"thumbnail.png"), FileMode.Create, FileAccess.Write, FileShare.Write)) fs.WriteByte(1);
        });
        // and the failure mode itself: write into a nested path WITHOUT creating the parent
        string np = Path.Combine(Path.Combine(baseDir,"nocreate"),"sub");
        Try("FileStream write into UNcreated nested (expect DirNotFound)", () => {
            using (var fs = new FileStream(Path.Combine(np,"x.bin"), FileMode.Create, FileAccess.Write)) fs.WriteByte(1);
        });

        Console.WriteLine("\n== done ==");
    }

    static void MoveCheck(string label, string baseDir, string name, bool nested) {
        string src = Path.Combine(baseDir, name+"_s"), dst = Path.Combine(baseDir, name+"_d");
        try {
            if (nested) { Directory.CreateDirectory(Path.Combine(src, ".metadata")); File.WriteAllText(Path.Combine(src, ".metadata", "t.png"), "x"); }
            else Directory.CreateDirectory(src);
            File.WriteAllText(Path.Combine(src, "f.txt"), "y");
        } catch {}
        string threw = "no throw";
        try { Directory.Move(src, dst); } catch (Exception e) { threw = e.GetType().Name+": "+e.Message; }
        bool moved = Directory.Exists(dst) && !Directory.Exists(src) && File.Exists(Path.Combine(dst, "f.txt"));
        Console.WriteLine("    {0,-24} threw=[{1}]  ACTUALLY MOVED={2}", label, threw, moved);
    }

    static void FileDelCheck(string label, string baseDir, string name, bool create) {
        string f = Path.Combine(baseDir, name+".bin");
        try { if (create) File.WriteAllText(f, "x"); } catch {}
        string threw = "no throw";
        try { File.Delete(f); } catch (Exception e) { threw = e.GetType().Name+": "+e.Message; }
        Console.WriteLine("    {0,-24} threw=[{1}]  GONE={2}", label, threw, !File.Exists(f));
    }

    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr FindFirstFileW(string path, out WIN32_FIND_DATAW d);
    [DllImport("kernel32.dll")] static extern bool FindClose(IntPtr h);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct WIN32_FIND_DATAW { public uint attr; public long c,a,w; public uint hi,lo,r0,r1;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string name;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=14)]  public string alt; }

    static void FindTest(string label, string path) {
        WIN32_FIND_DATAW d; IntPtr h = FindFirstFileW(path, out d);
        bool bad = (h.ToInt64()==-1);
        Console.WriteLine("    {0,-42} handle={1}  err={2}  {3}", label,
            bad?"INVALID(-1)":("0x"+h.ToInt64().ToString("x")), Marshal.GetLastWin32Error(),
            bad?"*** FindFirstFile FAILED ***":("first='"+d.name+"'"));
        if (!bad) FindClose(h);
    }

    static void DelCheck(string label, string baseDir, string name, bool withChild) {
        string d = Path.Combine(baseDir, name);
        try { Directory.CreateDirectory(withChild ? Path.Combine(d, "sub") : d);
              if (withChild) File.WriteAllText(Path.Combine(d, "sub", "f"), "x"); } catch {}
        string threw = "no throw";
        try { Directory.Delete(d, true); }
        catch (Exception e) { threw = e.GetType().Name + ": " + e.Message; }
        Console.WriteLine("    {0,-20} threw=[{1}]  ACTUALLY GONE={2}", label, threw, !Directory.Exists(d));
    }

    static void ManualDelete(string dir) {
        foreach (var f in Directory.GetFiles(dir)) File.Delete(f);
        foreach (var sub in Directory.GetDirectories(dir)) ManualDelete(sub);
        Directory.Delete(dir, false);   // non-recursive removal of the now-empty dir (works on Wine)
    }

    static void Try(string label, Action act) {
        try { act(); Console.WriteLine("    OK    {0}", label); }
        catch (Exception e) { Console.WriteLine("    *** {0}: \"{1}\"   [{2}]", e.GetType().Name, e.Message, label); }
    }

    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    static void CloseHandleWrap(IntPtr h){ CloseHandle(h); }
}
