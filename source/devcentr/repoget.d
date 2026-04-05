module devcentr.repoget;

import std.process;
import std.stdio;
import std.string;
import std.file;
import std.path;
import std.algorithm;

/**
 * Supported Version Control Systems
 */
enum VCS {
    Git,
    SVN,
    Hg,
    Jj,
    Darcs,
    Fossil,
    Bazaar,
    CVS,
    P4
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
 * Git Provider wrapping the 'git' CLI
 */
class GitProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["git", "clone", "--depth", "1", url, path]);
        if (wait(pid) != 0) throw new Exception("Git clone failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["git", "-C", path, "pull"]);
        if (wait(pid) != 0) throw new Exception("Git pull failed");
    }

    string status(string path) {
        auto res = execute(["git", "-C", path, "status", "--short"]);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["git", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Subversion Provider wrapping the 'svn' CLI
 */
class SvnProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["svn", "checkout", url, path]);
        if (wait(pid) != 0) throw new Exception("SVN checkout failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["svn", "update", path]);
        if (wait(pid) != 0) throw new Exception("SVN update failed");
    }

    string status(string path) {
        auto res = execute(["svn", "status", path]);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["svn", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Mercurial Provider wrapping the 'hg' CLI
 */
class HgProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["hg", "clone", url, path]);
        if (wait(pid) != 0) throw new Exception("Hg clone failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["hg", "pull", "-u", "-R", path]);
        if (wait(pid) != 0) throw new Exception("Hg pull failed");
    }

    string status(string path) {
        auto res = execute(["hg", "status", "-R", path]);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["hg", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Jujutsu Provider wrapping the 'jj' CLI
 */
class JjProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["jj", "git", "clone", url, path]);
        if (wait(pid) != 0) throw new Exception("Jj clone failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["jj", "git", "fetch", "--repository", path]);
        if (wait(pid) != 0) throw new Exception("Jj fetch failed");
    }

    string status(string path) {
        auto res = execute(["jj", "status", "--repository", path]);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["jj", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Darcs Provider wrapping the 'darcs' CLI
 */
class DarcsProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["darcs", "get", url, path]);
        if (wait(pid) != 0) throw new Exception("Darcs get failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["darcs", "pull", "--repodir", path]);
        if (wait(pid) != 0) throw new Exception("Darcs pull failed");
    }

    string status(string path) {
        auto res = execute(["darcs", "whatsnew", "--repodir", path]);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["darcs", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Fossil Provider wrapping the 'fossil' CLI
 */
class FossilProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["fossil", "clone", url, path ~ ".fossil"]);
        if (wait(pid) != 0) throw new Exception("Fossil clone failed");
        auto openPid = spawnProcess(["fossil", "open", path ~ ".fossil"], stdin, stdout, stderr, null, Config.none, path);
        if (wait(openPid) != 0) throw new Exception("Fossil open failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["fossil", "update"], stdin, stdout, stderr, null, Config.none, path);
        if (wait(pid) != 0) throw new Exception("Fossil update failed");
    }

    string status(string path) {
        auto res = execute(["fossil", "status"], null, Config.none, size_t.max, path);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["fossil", "version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Bazaar Provider wrapping the 'bzr' CLI
 */
class BazaarProvider : VCSProvider {
    void clone(string url, string path) {
        auto pid = spawnProcess(["bzr", "branch", url, path]);
        if (wait(pid) != 0) throw new Exception("Bazaar branch failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["bzr", "pull", "--directory", path]);
        if (wait(pid) != 0) throw new Exception("Bazaar pull failed");
    }

    string status(string path) {
        auto res = execute(["bzr", "status", "--directory", path]);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["bzr", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * CVS Provider wrapping the 'cvs' CLI
 */
class CvsProvider : VCSProvider {
    void clone(string url, string path) {
        // url should be in format :pserver:user@host:/path
        auto pid = spawnProcess(["cvs", "-d", url, "checkout", "-d", path, "."]);
        if (wait(pid) != 0) throw new Exception("CVS checkout failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["cvs", "update"], stdin, stdout, stderr, null, Config.none, path);
        if (wait(pid) != 0) throw new Exception("CVS update failed");
    }

    string status(string path) {
        auto res = execute(["cvs", "status"], null, Config.none, size_t.max, path);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["cvs", "--version"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Perforce Provider wrapping the 'p4' CLI
 */
class P4Provider : VCSProvider {
    void clone(string url, string path) {
        // url should be the depot path
        auto pid = spawnProcess(["p4", "sync", url ~ "/..."]);
        if (wait(pid) != 0) throw new Exception("P4 sync failed");
    }

    void pull(string path) {
        auto pid = spawnProcess(["p4", "sync"], stdin, stdout, stderr, null, Config.none, path);
        if (wait(pid) != 0) throw new Exception("P4 sync failed");
    }

    string status(string path) {
        auto res = execute(["p4", "status"], null, Config.none, size_t.max, path);
        return res.output;
    }

    bool isAvailable() {
        try { return execute(["p4", "-V"]).status == 0; } catch (Exception) { return false; }
    }
}

/**
 * Factory for creating the correct provider based on URL or metadata
 */
VCSProvider getProvider(string url) {
    if (url.endsWith(".git") || url.startsWith("git+")) return new GitProvider();
    if (url.startsWith("svn://") || url.canFind("/svn/")) return new SvnProvider();
    if (url.startsWith("hg+")) return new HgProvider();
    // Default to Git if unknown
    return new GitProvider();
}
