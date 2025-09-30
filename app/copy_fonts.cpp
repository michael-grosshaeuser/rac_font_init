// Copyright (c) 2024 Michael Grosshaeuser
// SPDX-License-Identifier: GPL-3.0-or-later

#include <filesystem>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

int main() {
  std::string src = "/fonts";
  std::string dst = "/font_volume";

  if (!fs::exists(src) || !fs::is_directory(src)) {
    std::cerr << "Source directory " << src << " not found." << std::endl;
    return 1;
  }

  if (!fs::exists(dst) || !fs::is_directory(dst)) {
    std::cerr << "Target directory" << dst << " not found." << std::endl;
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
    std::cout << "No .ttf-Files found." << std::endl;
  } else {
    std::cout << "Copy completed." << std::endl;
  }

  return 0;
}
