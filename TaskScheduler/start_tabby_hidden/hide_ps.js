var shell = WScript.CreateObject("WScript.Shell");
var args = WScript.Arguments;

var cmd = ""
for(var i=0; i < args.length; i++) {
  cmd += " " + args(i)
}
var ret = shell.Run("powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File" + cmd, 0, true);
WScript.Quit(ret);