#include <iostream>
#include "minIni.h"

int main(int argc, char* argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <ini-file> <section> <key>\n";
        return 1;
    }

    const char* filename = argv[1];
    const char* section = argv[2];
    const char* key = argv[3];

    char buffer[256];
    if (ini_gets(section, key, "", buffer, sizeof(buffer), filename) > 0) {
        std::cout << buffer << std::endl;
    } else {
        std::cerr << "Key not found\n";
        return 2;
    }

    return 0;
}
