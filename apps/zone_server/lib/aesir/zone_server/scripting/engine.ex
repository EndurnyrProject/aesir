defmodule Aesir.ZoneServer.Scripting.Engine do
  @moduledoc """
  Main script engine for executing Lua scripts in a sandboxed environment.
  """
  use GenServer

  require Logger

  alias Aesir.ZoneServer.Scripting.ROFunctions

  defstruct [:lua_state, :script_cache]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a script for a specific event with player context.
  """
  def execute_script(script_id, event, player_state) do
    GenServer.call(__MODULE__, {:execute, script_id, event, player_state})
  end

  @doc """
  Load a script into the engine.
  """
  def load_script(script_id, script_code) do
    GenServer.call(__MODULE__, {:load, script_id, script_code})
  end

  @doc """
  Clear all cached scripts.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @impl true
  def init(_opts) do
    lua_state =
      Lua.new()
      |> setup_sandbox()
      |> Lua.load_api(ROFunctions)

    state = %__MODULE__{
      lua_state: lua_state,
      script_cache: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, script_id, event, player_state}, _from, state) do
    result =
      case Map.get(state.script_cache, script_id) do
        nil ->
          {:error, :script_not_found}

        script_code ->
          execute_with_context(state.lua_state, script_code, event, player_state)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:load, script_id, script_code}, _from, state) do
    # Store the script code directly - we'll parse it during execution
    new_cache = Map.put(state.script_cache, script_id, script_code)
    {:reply, :ok, %{state | script_cache: new_cache}}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    {:reply, :ok, %{state | script_cache: %{}}}
  end

  defp setup_sandbox(lua_state) do
    dangerous_paths = [
      [:io],
      [:os],
      [:file],
      [:load],
      [:loadfile],
      [:dofile],
      [:loadstring],
      [:require],
      [:package],
      [:debug],
      [:rawget],
      [:rawset],
      [:setmetatable],
      [:getmetatable],
      [:collectgarbage],
      [:module]
    ]

    Enum.reduce(dangerous_paths, lua_state, fn path, state ->
      Lua.sandbox(state, path)
    end)
  end

  defp execute_with_context(lua_state, script_code, event, player_state) do
    lua_with_context =
      lua_state
      |> Lua.put_private(:current_player, player_state)
      |> Lua.put_private(:current_event, event)

    case Lua.eval!(lua_with_context, script_code) do
      {[script_table], updated_lua} ->
        script_map =
          cond do
            is_map(script_table) ->
              script_table

            is_list(script_table) ->
              Enum.into(script_table, %{}, fn
                {k, v} when is_binary(k) -> {k, v}
                {k, v} when is_atom(k) -> {Atom.to_string(k), v}
              end)

            true ->
              %{}
          end

        event_key = Atom.to_string(event)

        case Map.get(script_map, event_key) do
          nil ->
            {:ok, :no_handler}

          _handler ->
            lua_with_script = Lua.set!(updated_lua, [:script], script_table)

            handler_code = """
            return script.#{event_key}()
            """

            {[result], _final_lua} = Lua.eval!(lua_with_script, handler_code)
            {:ok, result}
        end

      {_, _} ->
        {:error, :invalid_script_format}
    end
  rescue
    error ->
      Logger.error("Script crashed: #{inspect(error)}")
      {:error, {:crash, error}}
  end
end
