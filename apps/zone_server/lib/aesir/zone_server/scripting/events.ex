defmodule Aesir.ZoneServer.Scripting.Events do
  @moduledoc """
  Event definitions and handlers for script execution.
  Maps game events to Lua script handlers.
  """

  @doc """
  List of valid event types that scripts can handle.
  """
  def valid_events do
    [
      # Item is used/consumed
      :on_use,
      # Equipment is worn
      :on_equip,
      # Equipment is removed
      :on_unequip,
      # Periodic timer tick
      :on_timer,
      # Player logs in
      :on_login,
      # Player logs out
      :on_logout,
      # Player dies
      :on_pc_die,
      # Player kills another player
      :on_pc_kill,
      # Player kills an NPC/monster
      :on_npc_kill,
      # Player casts a skill
      :on_cast_skill,
      # Player uses a skill
      :on_use_skill,
      # Player attacks
      :on_attack,
      # Item is consumed
      :on_consume,
      # Item is refined
      :on_refine
    ]
  end

  @doc """
  Alias for valid_events/0 for compatibility.
  """
  def all_events, do: valid_events()

  @doc """
  Check if an event is valid.
  """
  def valid_event?(event) when is_atom(event) do
    event in valid_events()
  end

  def valid_event?(_), do: false

  @doc """
  Get the Lua function name for an event.
  """
  def event_to_lua_name(:on_use), do: "on_use"
  def event_to_lua_name(:on_equip), do: "on_equip"
  def event_to_lua_name(:on_unequip), do: "on_unequip"
  def event_to_lua_name(:on_timer), do: "on_timer"
  def event_to_lua_name(:on_attack), do: "on_attack"
  def event_to_lua_name(:on_damaged), do: "on_damaged"
  def event_to_lua_name(:on_refine), do: "on_refine"
  def event_to_lua_name(:on_card), do: "on_card"
  def event_to_lua_name(:on_identify), do: "on_identify"
  def event_to_lua_name(:on_break), do: "on_break"
  def event_to_lua_name(:on_repair), do: "on_repair"
  def event_to_lua_name(_), do: nil

  @doc """
  Build a Lua script wrapper for an event handler.
  This ensures the script returns a proper table with event handlers.
  """
  def wrap_script_code(lua_code) do
    """
    -- User script wrapped in table format
    local script = {}

    #{lua_code}

    return script
    """
  end
end
