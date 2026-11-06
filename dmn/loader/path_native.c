#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
int32_t moondmn_path_link(const char *path) {
  wchar_t wide[32768];
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, 32768)) return -1;
  DWORD attr = GetFileAttributesW(wide);
  if (attr == INVALID_FILE_ATTRIBUTES) return -1;
  return (attr & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
}
#else
#include <sys/stat.h>
int32_t moondmn_path_link(const char *path) {
  struct stat info;
  if (lstat(path, &info) != 0) return -1;
  return S_ISLNK(info.st_mode);
}
#endif
