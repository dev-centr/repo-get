module devcentr.platform;

import std.process;
import std.string;
import std.file;
import std.path;
import std.algorithm;

/**
 * Platform information for equivalency mapping
 */
struct Platform {
    string os;         // windows, linux, macos, bsd
    string distro;     // ubuntu, fedora, arch, debian, etc.
    string arch;       // x86_64, aarch64, etc.
    bool elevated;     // has sudo/admin privileges
}

/**
 * Detect current platform facts
 */
Platform detectPlatform() {
    Platform p;

    // Detect OS
    version(Windows) p.os = "windows";
    else version(OSX) p.os = "macos";
    else version(linux) p.os = "linux";
    else version(FreeBSD) p.os = "bsd";
    else version(OpenBSD) p.os = "bsd";
    else version(NetBSD) p.os = "bsd";
    else p.os = "unknown";

    // Detect Arch
    version(X86_64) p.arch = "x86_64";
    else version(AArch64) p.arch = "aarch64";
    else version(X86) p.arch = "x86";
    else p.arch = "unknown";

    // Detect Distro (Linux only)
    if (p.os == "linux" && exists("/etc/os-release")) {
        auto content = readText("/etc/os-release");
        foreach (line; content.splitLines) {
            if (line.startsWith("ID=")) {
                p.distro = line[3..$].strip("\"");
            }
        }
    }

    // Detect Elevation
    version(Windows) {
        // Simple check for elevation on Windows
        try {
            auto res = execute(["net", "session"]);
            p.elevated = (res.status == 0);
        } catch (Exception) { p.elevated = false; }
    } else {
        try {
            auto res = execute(["id", "-u"]);
            p.elevated = (res.output.strip == "0");
        } catch (Exception) { p.elevated = false; }
    }

    return p;
}

/**
 * Get fact list for RuleEngine matching
 */
string[] getPlatformFacts() {
    auto p = detectPlatform();
    string[] facts;
    facts ~= "platform:" ~ p.os;
    if (p.distro != "") facts ~= "distro:" ~ p.distro;
    facts ~= "arch:" ~ p.arch;
    if (p.elevated) facts ~= "elevated:true";
    return facts;
}
