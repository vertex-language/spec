package ownership_test
build test

class Frame {
    pts: int64
}

func (f: Frame) init(pts: int64) {
    f.pts = pts
}

func (q: mut EncodeQueue) submit(f: var Frame) {
    q.count += 1
}

class EncodeQueue {
    count: int32
}

func (q: EncodeQueue) init() {
    q.count = 0
}

func test_transfer_submit_leaves_source_unusable_pattern() test -> Expected(int32, "1") {
    var queue = EncodeQueue()
    var frame = Frame(pts: 100)
    queue.submit(frame.transfer())
    return queue.count
}

func test_bare_submit_copies_and_source_survives() test -> Expected(bool, "1") {
    var queue = EncodeQueue()
    var frame = Frame(pts: 100)
    queue.submit(frame)         // COPY — frame survives
    return frame.pts == 100
}