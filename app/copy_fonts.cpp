#include <filesystem>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

int main() {
  std::string src = "/fonts";
  std::string dst = "/font_volume";

  if (!fs::exists(src) || !fs::is_directory(src)) {
    std::cerr << "Quellverzeichnis " << src << " existiert nicht." << std::endl;
    return 1;
  }

  if (!fs::exists(dst) || !fs::is_directory(dst)) {
    std::cerr << "Zielverzeichnis " << dst << " existiert nicht." << std::endl;
    return 1;
  }

  bool found = false;
  for (const auto &entry : fs::directory_iterator(src)) {
    if (entry.path().extension() == ".ttf") {
      fs::copy(entry.path(), dst + "/" + entry.path().filename().string(),
               fs::copy_options::overwrite_existing);
      found = true;
    }
  }

  if (!found) {
    std::cout << "Keine .ttf-Dateien gefunden." << std::endl;
  } else {
    std::cout << "Kopieren abgeschlossen." << std::endl;
  }

  return 0;
}