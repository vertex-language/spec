package error_handling_test
build test

struct Model {
    value: int32
}

func readFile(path: string) -> (string, string) {
    if path == "" {
        return "", "cannot open empty path"
    }
    return "config_text", ""
}

func parseConfig(text: string) -> (int32, string) {
    if text == "" {
        return 0, "empty config"
    }
    return 7, ""
}

func loadModel(path: string) -> (Model, string) {
    let text, err = readFile(path)
    if err != "" {
        return Model{value: 0}, err
    }

    let config, err2 = parseConfig(text)
    if err2 != "" {
        return Model{value: 0}, err2
    }

    return Model{value: config}, ""
}

func test_chain_success() test -> Expected(int32, "7") {
    let m, err = loadModel("real_path")
    if err != "" {
        return -1
    }
    return m.value
}

func test_chain_fails_at_first_step() test -> Expected(bool, "1") {
    let m, err = loadModel("")
    return err != ""
}

func test_chain_zero_value_on_first_failure() test -> Expected(int32, "0") {
    let m, err = loadModel("")
    return m.value
}