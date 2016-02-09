#include <stdexcept>
#include <string>
#include <sstream>
#include <vector>

#include "path.h"

namespace vmprobe { namespace path {

static std::vector<std::string> path_split(const std::string &path) {
    std::vector<std::string> vec;
    std::stringstream ss(path);
    std::string item;
    while (std::getline(ss, item, '/')) {
        if (!item.empty()) vec.push_back(item);
    }
    return vec;
}

static std::string path_join(std::vector<std::string> &vec) {
    std::string path;

    for (auto &p : vec) {
        path += "/";
        path += p;
    }

    if (path.empty()) return "/";

    return path;
}

std::string normalize(std::string &path) {
    if (path.size() < 1 || path[0] != '/') throw(std::runtime_error(std::string("path must start with /")));

    std::vector<std::string> components = path_split(path);
    std::vector<std::string> filtered;

    for (auto &p : components) {
        if (p == ".") {
            continue;
        } else if (p == "..") {
            if (!filtered.empty()) filtered.pop_back();
            continue;
        } else {
            filtered.push_back(p);
        }
    }

    return path_join(filtered);
}

}}
