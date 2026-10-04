defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb do
  @moduledoc """
  Fiber Lock (SC_SPIDERWEB). The holder is rooted by up to three webs (their
  group ids in `state.groups`) and loses half its FLEE.

  Fire against the holder gains 100 element ratio points (`DamageShared`:
  renewal adds them to the element row, pre-renewal doubles the damage). Each
  fire hit burns the web closest to running out; the hold lasts while a web
  remains. Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spiderweb,
    no_dispel: true,
    no_save: true,
    bypass_resistance: true,
    properties: [:debuff, :prevents_movement],
    flags: [:no_move],
    calc_flags: [:flee],
    icon: :spiderweb

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @impl true
  def modifiers(_instance, _context), do: %{flee_rate: -50}

  @impl true
  def absorb_damage(
        _target,
        %{state: %{groups: groups}} = instance,
        %{element: :fire, damage: damage},
        _context
      )
      when damage > 0 do
    case burn(groups) do
      [] -> {:remove, damage}
      left -> {:ok, damage, %{instance | state: Map.put(instance.state, :groups, left)}}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @impl true
  def on_expire(_target, %{state: %{groups: groups}}, _context) do
    Enum.each(groups, &Manager.destroy_async/1)
    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok

  # Destroys the live web with the least time left and returns the rest. Webs
  # already gone are dropped. With one web left, it is torn down by `on_expire`.
  defp burn(groups) do
    live = Enum.filter(groups, &match?(%Group{}, Storage.get(&1)))

    case live do
      [] ->
        []

      [_last] ->
        []

      _many ->
        shortest = Enum.min_by(live, &Storage.get(&1).expires_at)
        Manager.destroy_async(shortest)
        live -- [shortest]
    end
  end
end
