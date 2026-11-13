#include "secure_store.h"
#include <windows.h>
#include <wincrypt.h>
#include <shlobj.h>
#include <filesystem>
#include <stdexcept>
#include <string>
#include <regex>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
std::string Argument(const flutter::EncodableMap& args, const char* key) {
  auto found = args.find(Value(key));
  if (found == args.end() || !std::holds_alternative<std::string>(found->second))
    throw std::runtime_error("argument");
  return std::get<std::string>(found->second);
}
std::filesystem::path StorageDirectory() {
  PWSTR base = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE, nullptr, &base)))
    throw std::runtime_error("directory");
  auto path = std::filesystem::path(base) / L"DayMindSMART" / L"secure-v1";
  CoTaskMemFree(base);
  std::filesystem::create_directories(path);
  return path;
}
std::vector<BYTE> ReadBounded(const std::filesystem::path& path) {
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE,
      nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    if (GetLastError() == ERROR_FILE_NOT_FOUND) return {};
    throw std::runtime_error("read");
  }
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file, &size) || size.QuadPart <= 0 || size.QuadPart > 65536) {
    CloseHandle(file);throw std::runtime_error("size");
  }
  std::vector<BYTE> data(static_cast<size_t>(size.QuadPart));
  DWORD count = 0;
  bool ok = ReadFile(file, data.data(), static_cast<DWORD>(data.size()), &count, nullptr) != FALSE;
  CloseHandle(file);
  if (!ok || count != data.size()) throw std::runtime_error("read");
  return data;
}
void AtomicWrite(const std::filesystem::path& path, const BYTE* data, DWORD size) {
  wchar_t temporary[MAX_PATH]{};
  if (!GetTempFileNameW(path.parent_path().c_str(), L"dm", 0, temporary))
    throw std::runtime_error("temporary");
  HANDLE file = CreateFileW(temporary, GENERIC_WRITE, 0, nullptr, TRUNCATE_EXISTING,
      FILE_ATTRIBUTE_NORMAL, nullptr);
  DWORD count = 0;
  bool ok = file != INVALID_HANDLE_VALUE && WriteFile(file, data, size, &count, nullptr) && count == size && FlushFileBuffers(file);
  if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
  if (ok) ok = MoveFileExW(temporary, path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != FALSE;
  if (!ok) { DeleteFileW(temporary);throw std::runtime_error("write"); }
}
}

void HandleSecureCall(const flutter::MethodCall<Value>& call,
    std::unique_ptr<flutter::MethodResult<Value>> result) {
  try {
    const auto* args = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    if (!args) throw std::runtime_error("argument");
    const std::string key = Argument(*args, "key");
    static const std::regex scoped_key(R"(offline\.(session|installation)|production\.[a-z][a-z0-9-]{4,28}[a-z0-9]\.(session|installation))");
    if (key != "session" && key != "installation" && key != "test_probe" && !std::regex_match(key, scoped_key))
      throw std::runtime_error("key");
    auto path = StorageDirectory() / (key + ".dpapi");
    DATA_BLOB entropy{static_cast<DWORD>(key.size()), reinterpret_cast<BYTE*>(const_cast<char*>(key.data()))};
    if (call.method_name() == "read") {
      auto bytes = ReadBounded(path);
      if (bytes.empty()) { result->Success();return; }
      DATA_BLOB input{static_cast<DWORD>(bytes.size()), bytes.data()}, output{};
      if (!CryptUnprotectData(&input, nullptr, &entropy, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output))
        throw std::runtime_error("decrypt");
      if (output.cbData == 0 || output.cbData > 49152) {
        SecureZeroMemory(output.pbData, output.cbData);LocalFree(output.pbData);throw std::runtime_error("size");
      }
      std::string value(reinterpret_cast<char*>(output.pbData), output.cbData);
      SecureZeroMemory(output.pbData, output.cbData);LocalFree(output.pbData);
      result->Success(Value(value));
      SecureZeroMemory(value.data(), value.size());
    } else if (call.method_name() == "write") {
      std::string value = Argument(*args, "value");
      if (value.empty() || value.size() > 49152) throw std::runtime_error("size");
      DATA_BLOB input{static_cast<DWORD>(value.size()), reinterpret_cast<BYTE*>(value.data())}, output{};
      bool encrypted = CryptProtectData(&input, L"DayMind session v1", &entropy, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output) != FALSE;
      SecureZeroMemory(value.data(), value.size());
      if (!encrypted) throw std::runtime_error("encrypt");
      try { AtomicWrite(path, output.pbData, output.cbData); }
      catch (...) { LocalFree(output.pbData);throw; }
      LocalFree(output.pbData);result->Success();
    } else if (call.method_name() == "delete") {
      if (!DeleteFileW(path.c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND)
        throw std::runtime_error("delete");
      result->Success();
    } else { result->NotImplemented(); }
  } catch (...) {
    result->Error("SECURE_STORAGE", "Khong truy cap duoc kho phien dang nhap cua he dieu hanh.");
  }
}
