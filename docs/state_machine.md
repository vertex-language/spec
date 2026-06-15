Here is exactly what that transformation looks like.

Before languages had `async`/`await` compilers to do this for us automatically, C programmers working with UI frameworks (like GTK/GLib) or event-driven servers had to write these state machines entirely by hand. We called it "manual stack management" or "callback management."

### **1. The Normal (Synchronous) C Loop**

Here is a standard, blocking `for` loop. It asks for data, waits (blocks the thread) until it arrives, processes it, and repeats.

```c
#include <stdio.h>

// A dummy blocking function that stops the CPU thread until data arrives
char* blocking_network_read() {
    sleep(1); // Simulating a slow network
    return "data_payload";
}

void process_data_sync() {
    // Local variable lives safely on the CPU execution stack
    for (int i = 0; i < 3; i++) {
        printf("Fetching chunk %d...\n", i);
        
        // THE PROBLEM: The thread completely freezes right here.
        // If this is a UI thread, the whole application hangs.
        char* data = blocking_network_read(); 
        
        printf("Processed chunk %d: %s\n", i, data);
    }
    printf("Done!\n");
}

```

This is beautiful and easy to read. But if you run this inside a GLib Main Loop, your application freezes for 3 seconds. The main loop cannot process button clicks or redraw the screen because the thread is stuck waiting inside `blocking_network_read`.

---

### **2. The GLib-Style State Machine (Asynchronous)**

To fix the freezing, we have to completely destroy the `for` loop. We must chop the function into pieces so that we can *return control to the GLib main loop* while we wait for the network.

To do this, we manually recreate the execution stack on the heap using a `struct`, and replace the `for` loop with a `switch` statement.

```c
#include <glib.h>
#include <stdio.h>

// 1. THE CONTEXT STRUCT
// We must move our local variables off the stack and into heap memory.
typedef struct {
    int i;       // Replaces the 'int i' from the for loop
    int state;   // Tracks where we are in the loop's execution
} LoopState;

// 2. THE STATE MACHINE (Callback)
// This function is repeatedly called by the GLib Main Loop.
gboolean process_data_async(gpointer user_data) {
    LoopState* sm = (LoopState*)user_data;

    switch (sm->state) {
        case 0: // LOOP CONDITION CHECK
            if (sm->i < 3) {
                printf("Requesting chunk %d asynchronously...\n", sm->i);
                
                // We pretend to fire off a non-blocking network request here.
                // start_async_network_read(...);
                
                sm->state = 1; // Update state so we know what to do next time
                
                // RETURN CONTROL TO GLIB! The thread is now free to do UI work.
                // G_SOURCE_CONTINUE tells GLib to keep calling this function.
                return G_SOURCE_CONTINUE; 
            } else {
                printf("Done!\n");
                g_free(sm); // Clean up our manual "stack"
                
                // G_SOURCE_REMOVE tells GLib to stop calling this function.
                return G_SOURCE_REMOVE; 
            }

        case 1: // WAKING UP (Data has arrived)
            // In a real app, this case might be triggered by a network callback
            printf("Processed chunk %d\n", sm->i);
            
            sm->i++;       // Increment our loop variable
            sm->state = 0; // Jump back to the loop condition
            
            return G_SOURCE_CONTINUE; 
    }
    
    return G_SOURCE_REMOVE;
}

// 3. THE KICKOFF FUNCTION
void start_async_loop() {
    // Allocate the state machine on the heap
    LoopState* sm = g_new(LoopState, 1);
    sm->i = 0;
    sm->state = 0;

    // Hand the state machine over to the GLib Main Loop.
    // GLib will call process_data_async(sm) when the thread is idle.
    g_idle_add(process_data_async, sm);
}

```

### **The Takeaway**

When you look at the GLib example above, you are looking at the exact blueprint of what a Rust, C#, or JavaScript compiler does for you when you type `async` and `await`.

* The compiler auto-generates the `LoopState` struct.
* The compiler auto-generates the `switch` statement.
* The compiler automatically wires up the `return` calls to the invisible event loop.

Go looked at this exact C-to-GLib transformation and said, *"No. Writing code that way is a nightmare, and compiler-generated state machines make stack traces unreadable. We are just going to write a runtime that pauses the actual thread stack in memory instead."*


You are exactly right. That is the fundamental trade-off the Go team made. They sacrificed absolute, raw hardware performance and memory efficiency in exchange for incredible developer ergonomics.

When you compare a Go server to a server written in a language that uses compile-time state machines (like Rust, Zig, or your design for Vertex), Go is definitively slower and heavier.

Here is exactly where that "mini OS" runtime bottlenecks a server under extreme load:

### 1. The Garbage Collector (The Real Speed Killer)

Because Go allocates a mini 2KB stack on the heap for every single goroutine, the Go Garbage Collector (GC) has to work overtime. It constantly scans memory to see which goroutines have finished and which stacks can be freed. When a Go server gets hit with massive traffic, the GC has to steal CPU cycles away from your actual application logic to clean up the mess. This causes unpredictable latency spikes (the infamous "GC pauses").

State machines, on the other hand, don't inherently require a heavy garbage collector. When an `async` struct finishes its final state, the memory is just deterministically freed or dropped.

### 2. Cache Thrashing (The Silent Killer)

Modern CPUs get their speed from the L1 and L2 memory caches. If you keep the same data on the same CPU core, it runs blazingly fast.
Go's M:N scheduler is constantly moving goroutines around. A goroutine might start on Core 1, go to sleep waiting for network data, and wake up on Core 4. When it wakes up on Core 4, the CPU cache is completely cold. It has to fetch all your variables from main RAM again, which takes hundreds of wasted CPU cycles.

An `async` event loop usually pins itself to a single CPU core. The state machines live in that core's cache, resulting in massive mechanical sympathy with the hardware.

### 3. The 10K Connection Problem

If you have 10,000 idle websocket connections (like a chat app):

* **Go:** 10,000 goroutines × 2KB minimum stack = **20 Megabytes** of RAM minimum, just sitting there doing nothing.
* **State Machine:** 10,000 structs × 32 bytes (just a few state variables) = **320 Kilobytes** of RAM.

When you scale a server to millions of connections, Go will max out your server's RAM and force you to buy more AWS instances long before a state-machine-based server breaks a sweat.

---

### The Reality Check

To be fair to Go, its user-space context switching is still *vastly* faster than older languages that use one real OS thread per connection (like traditional Java, Python, or Ruby servers). But in the arena of ultra-high-performance systems languages, Go's heavy runtime keeps it out of the number one spot.

By opting for compile-time state machines for Vertex's `async` modifier, you are guaranteeing that your compiled C binaries will have zero hidden scheduling overhead.

Since these state machines will essentially just be heap-allocated C structs when compiled, how do you plan to handle the memory cleanup for them when a task finishes—will the generated C code rely on the `.delete()` reference counting you established for classes, or will the event loop just `free()` them directly?