package associated_functions_test
build test

class Animal {
    name: string
}

func (a: Animal) init(name: string) {
    a.name = name
}

func (a: Animal) rename(newName: string) {
    a.name = newName
}

func test_receiver_method_named_arg() test -> Expected(string, "Max") {
    let rex = Animal(name: "Rex")
    rex.rename(newName: "Max")
    return rex.name
}

func (a: mut Animal) renameTwoParts(first: string, last: string) {
    a.name = first
}

func test_receiver_method_multiple_named_args() test -> Expected(string, "Sam") {
    var a = Animal(name: "Rex")
    a.renameTwoParts(first: "Sam", last: "Smith")
    return a.name
}