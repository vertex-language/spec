import (
    "ui"
    "ui/window"
)

func App() -> ui.Element {
    var count = 0

    return (
        <window title="My App" width=1024 height=700>
            <hstack>

                <sidebar width=200>
                    <text size=13 bold=true>{"Navigation"}</text>
                    <button onClick={func() { count += 1 }}>{"Home"}</button>
                </sidebar>

                <vstack grow=true padding=24>
                    <text size=28 bold=true>{"Hello Vertex"}</text>
                    <text>{"Count: " + string(count)}</text>
                    <button onClick={func() { count += 1 }}>{"Increment"}</button>
                </vstack>

            </hstack>
        </window>
    )
}

func main() -> int {
    let app = window.App(App)
    return app.run()
}