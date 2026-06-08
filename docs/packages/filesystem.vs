package main

import (
    fs    "os/filesystem"
    path  "os/filesystem/path"
    watch "os/filesystem/watch"
)

// ---------------------------------------------------------------
// File ops
// ---------------------------------------------------------------

func readFile(p: string) -> Result(string, string) {
    let file = fs.open(p, fs.Mode.read).try()
    defer file.close()

    var buf = [uint8](repeating: 0, count: file.size())
    let n   = file.read(into: &buf).try()

    return Result(Ok, string(buf.slice(0, n)))
}

func writeFile(p: string, data: string) -> Result((), string) {
    let file = fs.create(p).try()
    defer file.close()

    file.write(data: data.bytes()).try()
    return Result(Ok, ())
}

func appendFile(p: string, line: string) -> Result((), string) {
    let file = fs.open(p, fs.Mode.append).try()
    defer file.close()

    file.write(data: line.bytes()).try()
    return Result(Ok, ())
}

// ---------------------------------------------------------------
// Directory scan
// ---------------------------------------------------------------

struct FileEntry {
    var name:     string
    var fullPath: string
    var ext:      string
    var size:     int
    var modified: uint64
}

func scanDir(dir: string) -> Result([FileEntry], string) {
    var entries = [FileEntry]()

    fs.walk(dir, func(entry: fs.Entry) {
        if entry.isDir { return }

        entries.push(FileEntry{
            name:     path.basename(entry.path),
            fullPath: entry.path,
            ext:      path.ext(entry.path),
            size:     entry.stats.size,
            modified: entry.stats.modified,
        })
    }).try()

    entries.sort(func(a: FileEntry, b: FileEntry) -> int {
        return int(b.modified) - int(a.modified)
    })

    return Result(Ok, entries)
}

// ---------------------------------------------------------------
// Watcher
// ---------------------------------------------------------------

func watchLoop(dir: string, ch: channel watch.Event) thread {
    let watcher = watch.Watcher(dir: dir, recursive: true)
    defer watcher.delete()

    while true {
        let event = watcher.next().try()
        ch.send(event)
    }
}

// ---------------------------------------------------------------
// Index
// ---------------------------------------------------------------

struct IndexEntry {
    var path:  string
    var lines: int
    var bytes: int
}

func index(p: string) -> Result(IndexEntry, string) {
    let contents = readFile(p).try()

    var lines = 0
    contents.forEach(func(c: char) {
        if c == "\n" { lines += 1 }
    })

    return Result(Ok, IndexEntry{
        path:  p,
        lines: lines,
        bytes: contents.len,
    })
}

// ---------------------------------------------------------------
// Entry
// ---------------------------------------------------------------

func main() -> int {
    let dir     = "./data"
    let logPath = "./index.log"

    let entries = scanDir(dir).try()

    entries.forEach(func(e: FileEntry) {
        if e.ext != ".txt" { return }

        let entry = index(e.fullPath).try()
        let line  = e.name + " — " + string(entry.lines) + " lines\n"

        appendFile(logPath, line).try()
    })

    let ch: channel watch.Event = Channel(size: 32)

    
    watchLoop(dir: dir, ch: ch).spawn()

    while true {
        let event = ch.receive()

        switch event.kind {

        case watch.EventKind.created:
            let entry = index(event.path).try()
            let line  = "created: "  + path.basename(event.path)
                      + " "          + string(entry.lines) + " lines\n"
            appendFile(logPath, line).try()

        case watch.EventKind.modified:
            let entry = index(event.path).try()
            let line  = "modified: " + path.basename(event.path)
                      + " "          + string(entry.bytes) + " bytes\n"
            appendFile(logPath, line).try()

        case watch.EventKind.deleted:
            let line = "deleted: "  + path.basename(event.path) + "\n"
            appendFile(logPath, line).try()

        case watch.EventKind.renamed:
            let line = "renamed: "  + path.basename(event.path) + "\n"
            appendFile(logPath, line).try()
        }
    }

    return 0
}