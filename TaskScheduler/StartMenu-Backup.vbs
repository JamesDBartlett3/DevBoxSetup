Set fso = CreateObject("Scripting.FileSystemObject")
Set ws = CreateObject("WScript.Shell")

backupRoot = ws.ExpandEnvironmentStrings("%USERPROFILE%\Documents\StartMenuBackups")
source = ws.ExpandEnvironmentStrings("%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin")

If Not fso.FileExists(source) Then WScript.Quit 1
If Not fso.FolderExists(backupRoot) Then fso.CreateFolder backupRoot

' Only backup if the file has actually changed since last backup
lastBackup = GetLastBackup(backupRoot)
If Not (lastBackup = "") Then
    Set stream1 = CreateObject("ADODB.Stream")
    Set stream2 = CreateObject("ADODB.Stream")
    stream1.Type = 1 : stream1.Open : stream1.LoadFromFile source
    stream2.Type = 1 : stream2.Open : stream2.LoadFromFile lastBackup
    If stream1.Size = stream2.Size Then
        buf1 = stream1.Read : buf2 = stream2.Read
        If buf1 = buf2 Then WScript.Quit 0
    End If
    stream1.Close : stream2.Close
End If

' Save timestamped copy
ts = Year(Now) & "-" & Right("0" & Month(Now), 2) & "-" & Right("0" & Day(Now), 2) & "_" & _
    Right("0" & Hour(Now), 2) & "-" & Right("0" & Minute(Now), 2) & "-" & Right("0" & Second(Now), 2)
fso.CopyFile source, backupRoot & "\start2_" & ts & ".bin"

' Clean up backups older than 30 days
cutoff = DateAdd("d", -30, Now)
For Each f In fso.GetFolder(backupRoot).Files
    If Left(f.Name, 8) = "start2_" And Right(f.Name, 4) = ".bin" Then
        If f.DateLastModified < cutoff Then f.Delete True
    End If
Next

Function GetLastBackup(folder)
    Set mostRecent = Nothing
    For Each f In fso.GetFolder(folder).Files
        If Left(f.Name, 8) = "start2_" And Right(f.Name, 4) = ".bin" Then
            If mostRecent Is Nothing Then
                Set mostRecent = f
            ElseIf f.DateLastModified > mostRecent.DateLastModified Then
                Set mostRecent = f
            End If
        End If
    Next
    If mostRecent Is Nothing Then
        GetLastBackup = ""
    Else
        GetLastBackup = mostRecent.Path
    End If
End Function
