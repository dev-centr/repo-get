module devcentr.repoget;

import std.process;
import std.stdio;
import std.string;
import std.file;
import std.path;
import std.algorithm;
import std.regex;
import std.container;
import sdlang;

// Equivalence Engine Core
import equivalence.engine;
import equivalence.path;
import devcentr.platform;

/**
 * Metadata for a VCS Profile defined in SDL
 */
struct VCSProfile {
    string name;
    string[] matchers;
    string[] checkCmd;
    string[] cloneCmd;
    string[] pullCmd;
    string[] statusCmd;
    string[] openCmd;
    string[] installCmd; // [NEW] Installation command mapping
}

/**
 * Generic VCS Provider that executes commands based on dynamic profiles
 */
class GenericVCSProvider : VCSProvider {
    private VCSProfile profile;

    this(VCSProfile profile) {
        this.profile = profile;
    }

    void clone(string url, string path) {
        if (!isAvailable()) {
            writeln("Warning: ", profile.name, " is not available. Attempting to install...");
            install();
        }

        if (profile.cloneCmd.length == 0) throw new Exception("Clone command not defined for " ~ profile.name);
        
        auto cmd = interpolate(profile.cloneCmd, url, path);
        auto pid = spawnProcess(cmd);
        if (wait(pid) != 0) throw new Exception(profile.name ~ " clone failed: " ~ cmd.join(" "));

        if (profile.openCmd.length > 0) {
            auto ocmd = interpolate(profile.openCmd, url, path);
            auto opid = spawnProcess(ocmd, stdin, stdout, stderr, null, Config.none, path);
            if (wait(opid) != 0) throw new Exception(profile.name ~ " open failed");
        }
    }

    void pull(string path) {
        if (profile.pullCmd.length == 0) throw new Exception("Pull command not defined for " ~ profile.name);
        
        auto cmd = interpolate(profile.pullCmd, "", path);
        auto pid = spawnProcess(cmd, stdin, stdout, stderr, null, Config.none, path);
        if (wait(pid) != 0) throw new Exception(profile.name ~ " pull failed");
    }

    string status(string path) {
        if (profile.statusCmd.length == 0) return "Status not supported for " ~ profile.name;
        
        auto cmd = interpolate(profile.statusCmd, "", path);
        auto res = execute(cmd, null, Config.none, size_t.max, path);
        return res.output;
    }

    bool isAvailable() {
        if (profile.checkCmd.length == 0) return true;
        try {
            return execute(profile.checkCmd).status == 0;
        } catch (Exception) {
            return false;
        }
    }

    /**
     * Attempt to install the provider using platform-specific rules
     */
    void install() {
        // Use libequivalence to resolve 'install-vcs' intent
        auto engine = new RuleEngine();
        engine.parseRules(import("bootstrap.sdl"));
        
        auto facts = getPlatformFacts();
        // Resolve intent: install-<vcs-name>
        string intent = "install-" ~ profile.name.toLower();
        
        // Match rules based on facts
        // Simple implementation: iterate rules and check matchers
        foreach(rule; engine.rules) {
             // In a full implementation, we'd use intent resolution.
             // For bootstrap, we'll look for replace rules that match the intent name.
             if (rule.type == "replace" && rule.target.startsWith(intent)) {
                 // Check if it's executable
                 auto cmdParts = rule.replacement.split(" ");
                 writeln("Executing installation: ", rule.replacement);
                 auto pid = spawnProcess(cmdParts);
                 if (wait(pid) == 0) {
                     writeln("Successfully installed ", profile.name);
                     return;
                 }
             }
        }
        throw new Exception("Could not find a valid installation path for " ~ profile.name ~ " on this platform.");
    }

    private string[] interpolate(string[] args, string url, string path) {
        string[] result;
        foreach (arg; args) {
            auto a = arg.replace("$URL", url).replace("$PATH", path);
            result ~= a;
        }
        return result;
    }
}

/**
 * Universal interface for VCS operations
 */
interface VCSProvider {
    void clone(string url, string path);
    void pull(string path);
    string status(string path);
    bool isAvailable();
}

/**
 * Shell-based downloader using Equivalence bootstrap rules
 */
class BootstrapDownloader {
    static void download(string url, string path) {
        auto engine = new RuleEngine();
        engine.parseRules(import("bootstrap.sdl"));
        
        // Find a downloader that works
        foreach (rule; engine.rules) {
            if (rule.type == "replace" && rule.target.startsWith("download-url")) {
                auto cmdStr = rule.replacement.replace("$URL", url).replace("$PATH", path);
                auto cmdParts = cmdStr.split(" ");
                
                // Check if the tool itself exists (e.g., 'curl' or 'wget')
                try {
                    auto check = execute([cmdParts[0], "--version"]);
                    if (check.status == 0) {
                        writeln("Downloading using: ", cmdParts[0]);
                        auto pid = spawnProcess(cmdParts);
                        if (wait(pid) == 0) return;
                    }
                } catch (Exception) {}
            }
        }
        throw new Exception("No suitable downloader found (curl/wget/powershell). Please install one.");
    }
}

/**
 * Manager to handle loading and updating VCS profiles
 */
class ProfileManager {
    private VCSProfile[string] profiles;
    private static const string DEFAULT_SDL = import("vcs-profiles.sdl");
    private string cachePath;

    this() {
        cachePath = buildPath(environment.get("USERPROFILE"), ".dev-centr", "repo-get", "vcs-profiles.sdl");
        loadAll();
    }

    void loadAll() {
        // 1. Load built-in
        parseSdl(DEFAULT_SDL);

        // 2. Load from cache (overlay)
        if (exists(cachePath)) {
            try { parseSdl(readText(cachePath)); } catch (Exception e) { 
                writeln("Warning: Failed to parse cached profiles: ", e.msg);
            }
        }
    }

    void updateFromRemote() {
        string url = "https://raw.githubusercontent.com/dev-centr/repo-get/main/vcs-profiles.sdl";
        try {
            string tmpPath = cachePath ~ ".tmp";
            BootstrapDownloader.download(url, tmpPath);
            
            auto content = readText(tmpPath);
            if (content.canFind("vcs")) {
                string d = dirName(cachePath);
                if (!exists(d)) mkdirRecurse(d);
                std.file.rename(tmpPath, cachePath);
                parseSdl(content);
                writeln("Updated VCS profiles from GitHub.");
            }
        } catch (Exception e) {
            writeln("Warning: Could not update profiles from GitHub: ", e.msg);
        }
    }

    private void parseSdl(string content) {
        Tag root = parseSource(content);
        foreach (tag; root.tags) {
            if (tag.name == "vcs") {
                VCSProfile p;
                p.name = tag.values[0].get!string;
                
                foreach (t; tag.tags) {
                    string[] vals;
                    foreach (v; t.values) vals ~= v.get!string;

                    if (t.name == "matcher") p.matchers = vals;
                    else if (t.name == "check") p.checkCmd = vals;
                    else if (t.name == "clone") p.cloneCmd = vals;
                    else if (t.name == "pull") p.pullCmd = vals;
                    else if (t.name == "status") p.statusCmd = vals;
                    else if (t.name == "open") p.openCmd = vals;
                    else if (t.name == "install") p.installCmd = vals;
                }
                profiles[p.name] = p;
            }
        }
    }

    VCSProvider findProvider(string url) {
        foreach (profile; profiles.values) {
            foreach (m; profile.matchers) {
                if (matchFirst(url, regex(m))) return new GenericVCSProvider(profile);
            }
        }
        // Default to git if no match
        if ("git" in profiles) return new GenericVCSProvider(profiles["git"]);
        return null;
    }
}

private ProfileManager _manager;

/**
 * Singleton-ish access to the manager
 */
ProfileManager getManager() {
    if (_manager is null) _manager = new ProfileManager();
    return _manager;
}

/**
 * Factory for creating the correct provider based on URL or metadata
 */
VCSProvider getProvider(string url) {
    return getManager().findProvider(url);
}
