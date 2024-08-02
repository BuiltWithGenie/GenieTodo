using GenieFramework
@genietools

# Define a mutable struct to represent a Todo item
mutable struct Todo
    id::Int
    text::String
    completed::Bool
end

# Define the reactive app using Stipple.jl's @app macro
@app GenieTodo begin
    # Define reactive input variables
    @in new_todo = ""  # Holds the text for a new todo
    @in filter = "all"  # Current filter state (all, active, completed)
    @in process_new_todo = false  # Trigger for adding a new todo
    @in clear_completed = false  # Trigger for clearing completed todos
    @in delete_todo = 0  # ID of the todo to be deleted
    @in toggle_todo = 0  # ID of the todo to be toggled

    # Define private and output variables
    @private todos = Todo[]  # List of all todos (not directly accessible from the frontend)
    @out active_todos = 0  # Count of active todos
    @out completed_todos = 0  # Count of completed todos
    @out filtered_todos = Todo[]  # List of filtered todos based on current filter

    # Reactive handler for changes in the todos list
    @onchange todos begin
        @info "todos changed" todos
        # Update counts of active and completed todos
        active_todos = length([todo for todo in todos if !todo.completed])
        completed_todos = length(todos) - active_todos
        filtered_todos = update_filtered_todos(filter, todos)
    end

    # Reactive handler for changes in the filter
    @onchange filter begin
        @info "filter changed" filter
        filtered_todos = update_filtered_todos(filter, todos)
    end

    # Function to update the filtered_todos based on the current filter
    function update_filtered_todos(filter, todos)
        @info "update_filtered_todos called" filter
        if filter == "active"
            filtered_todos = [todo for todo in todos if !todo.completed]
        elseif filter == "completed"
            filtered_todos = [todo for todo in todos if todo.completed]
        else
            filtered_todos = todos
        end

        return filtered_todos
    end

    # Reactive handler for adding a new todo
    @onchange process_new_todo begin
        @info "processing new todo" new_todo process_new_todo
        todos = add_todo(new_todo, todos)
        new_todo = ""  # Clear the input field
        filter = "active"  # Switch to active filter after adding
    end

    # Function to add a new todo to the list
    function add_todo(text, todos)
        @info "add_todo called" text
        if !isempty(strip(text))
            push!(todos, Todo(length(todos) + 1, strip(text), false))
        end
        return todos
    end

    # Reactive handler for toggling a todo's completed status
    @onchange toggle_todo begin
        toggle_todo <= 0 && return

        @info "toggle_todo called" toggle_todo
        for todo in todos
            if todo.id == toggle_todo
                todo.completed = !todo.completed
                break
            end
        end
        toggle_todo = 0  # Reset the trigger
        todos = todos # Update the todos list by triggering the onchange handler
    end

    # Reactive handler for deleting a todo
    @onchange delete_todo begin
        delete_todo <= 0 && return

        @info "delete_todo called" delete_todo
        deleteat!(todos, findfirst(t -> t.id == delete_todo, todos))
        delete_todo = 0  # Reset the trigger
        todos = todos # Update the todos list by triggering the onchange handler
    end

    # Reactive handler for clearing completed todos
    @onchange clear_completed begin
        clear_completed || return

        @info "clear_completed called"
        filter!(t -> !t.completed, todos)
        clear_completed = false  # Reset the trigger
        todos = todos # Update the todos list by triggering the onchange handler
        filter = "active"  # Switch to active filter after clearing
    end
end

# Define computed properties to identify the current filter state and style the filter buttons
Stipple.jscomputed(::GenieTodo) = """
  filterAll: function() {
    return this.filter == 'all';
  },
  filterActive: function() {
    return this.filter == 'active';
  },
  filterCompleted: function() {
    return this.filter == 'completed';
  }
"""

# Function to define custom CSS styles
function custom_styles()
    ["""
    <style>
        body { background-color: #f4f4f4; }
        .todo-container { max-width: 600px; margin: auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .todo-header { text-align: center; color: #007bff; padding-bottom: 20px; }
        .todo-input { margin-bottom: 20px; }
        .todo-list { list-style-type: none; padding: 0; }
        .todo-item { display: flex; align-items: center; margin-bottom: 10px; padding: 10px; border-radius: 4px; background-color: #f8f9fa; }
        .todo-item label { margin-left: 10px; flex-grow: 1; }
        .todo-item button { padding: 2px 8px; }
        .todo-filters { margin-bottom: 20px; }
        .todo-filters .btn { margin-right: 5px; }
        .todo-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 20px; }
        .btn-focused { background-color: #007bff; color: white; }
        [v-cloak] { display: none; }
    </style>
    """]
end

# Define the UI using Stipple.jl's HTML DSL
function ui()
    # Add Bootstrap CSS
    Stipple.Layout.add_css("https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css")
    # Add custom styles
    Stipple.Layout.add_css(custom_styles)

    [
        section(class="todo-container", v__cloak=true, [
            header(class="todo-header", [
                h1("My Todo List")
            ]),
            section(class="todo-input", [
                # Input field for new todo, bound to new_todo variable
                input(class="form-control", placeholder="What needs to be done?", @bind(:new_todo), @on("keyup.enter", "process_new_todo = !process_new_todo"))
            ]),
            section(class="todo-filters", [
                # Filter buttons
                button("All ({{active_todos + completed_todos}})", class="btn btn-outline-primary", (class!)="{ 'btn-focused' : filterAll }", @on("click", "filter = 'all'")),
                button("Active ({{active_todos}})", class="btn btn-outline-primary", (class!)="{ 'btn-focused' : filterActive }", @on("click", "filter = 'active'")),
                button("Completed ({{completed_todos}})", class="btn btn-outline-primary", (class!)="{ 'btn-focused' : filterCompleted }", @on("click", "filter = 'completed'")),
                button("Clear completed", class="btn btn-outline-danger", @on("click", "clear_completed = true"))
            ]),
            section(class="todo-list", [
                ul(class="todo-list", [
                    # List of todos, using @recur for iteration
                    li(class="todo-item", @recur("todo in filtered_todos"), (key!)="todo.id", [
                        # Checkbox for toggling todo status
                        input(type="checkbox", class="form-check-input", @on("change", "toggle_todo = todo.id"), (checked!)="todo.completed", (id!)="'todo-' + todo.id"),
                        # Todo text
                        label(class="form-check-label", "{{ todo.text }}", (for!)="'todo-' + todo.id"),
                        # Delete button
                        button("×", class="btn btn-sm btn-outline-danger", @on("click", "delete_todo = todo.id"))
                    ])
                ])
            ]),
            footer(class="todo-footer", [
                # Display count of active todos
                span("{{ active_todos }} todos left", class="text-muted")
            ])
        ])
    ]
end

# Define the route for the todo app
@page("/", ui(), model = GenieTodo)

# Start the Genie.jl server
up(async=false)