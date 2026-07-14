package ownership_test
build test

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func test_weak_upgrade_succeeds_while_alive() test -> Expected(int32, "1") {
    var a = shared(Widget(id: 1))
    var w = weak(a)

    let s, err = w.upgrade()
    if err != "" {
        return -1
    }
    return s.id
}

func test_weak_upgrade_fails_after_drop() test -> Expected(bool, "1") {
    var a = shared(Widget(id: 1))
    var w = weak(a)

    drop(a)

    let s, err = w.upgrade()
    return err != ""
}

func test_weak_typed_binding() test -> Expected(int32, "5") {
    var a = shared(Widget(id: 5))
    var w: weak Widget = weak(a)

    let s, err = w.upgrade()
    if err != "" {
        return -1
    }
    return s.id
}

class FileSession {
    active_chunk: DataChunk
    session_key:  string = "AUTH_TKT_XYZ"
}

class DataChunk {
    parent: weak FileSession
    payload: []uint8
}

func (s: shared FileSession) init() {
    s.active_chunk = DataChunk(parent: weak(s))
}

func (c: DataChunk) validate_and_process() -> string {
    let s, err = c.parent.upgrade()
    if err == "" {
        let key = s.session_key
        return key
    }
    return ""
}

func test_back_reference_via_weak() test -> Expected(string, "AUTH_TKT_XYZ") {
    var s = shared(FileSession())
    return s.active_chunk.validate_and_process()
}