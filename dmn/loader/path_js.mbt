///|
#external
priv type FileStat

///|
#module("node:fs")
extern "js" fn lstat(path : String) -> FileStat = "lstatSync"

///|
extern "js" fn checked_link(stat : (String) -> FileStat, path : Bytes) -> Int32 =
  #| (stat, path) => { try { return stat(new TextDecoder().decode(path.subarray(0, path.length - 1))).isSymbolicLink() ? 1 : 0; } catch { return -1; } }

///|
fn path_link(path : Bytes) -> Int32 {
  checked_link(lstat, path)
}
