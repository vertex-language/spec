package structs_test
build test

struct Vec2 {
    x: float32
    y: float32
}

struct Player {
    id:       int32
    position: Vec2
    health:   int32
}

func test_struct_array_push_and_read() test -> Expected(int32, "1") {
    var players: []Player = []
    players.push(Player{
        id:       1,
        position: Vec2{x: 0.0, y: 0.0},
        health:   100,
    })
    return players[0].id
}

func test_struct_array_field_read() test -> Expected(int32, "100") {
    var players: []Player = []
    players.push(Player{
        id:       1,
        position: Vec2{x: 0.0, y: 0.0},
        health:   100,
    })
    let hp = players[0].health
    return hp
}

func test_struct_array_field_mutation() test -> Expected(int32, "50") {
    var players: []Player = []
    players.push(Player{
        id:       1,
        position: Vec2{x: 0.0, y: 0.0},
        health:   100,
    })
    players[0].health = 50
    return players[0].health
}

func test_struct_array_nested_field_read() test -> Expected(float32, "0.000000") {
    var players: []Player = []
    players.push(Player{
        id:       1,
        position: Vec2{x: 0.0, y: 0.0},
        health:   100,
    })
    return players[0].position.x
}

func test_struct_array_multiple_elements() test -> Expected(int32, "2") {
    var players: []Player = []
    players.push(Player{id: 1, position: Vec2{x: 0.0, y: 0.0}, health: 100})
    players.push(Player{id: 2, position: Vec2{x: 1.0, y: 1.0}, health: 80})
    return players[1].id
}