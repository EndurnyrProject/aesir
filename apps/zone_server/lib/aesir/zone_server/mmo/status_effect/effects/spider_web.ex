defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb do
  @moduledoc """
  Fiber Lock (SC_SPIDERWEB). The holder is rooted by up to three webs (their
  group ids in `state.groups`) and loses half its FLEE. Fire burns the webs: the
  first fire hit ends the status and every web, and is strengthened. Renewal adds
  100 ratio points to the fire element step; pre-renewal doubles the damage.
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

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def modifiers(_instance, _context), do: %{flee_rate: -50}

  @impl true
  def absorb_damage(target, _instance, %{element: :fire, damage: damage}, _context)
      when damage > 0 do
    case GameMode.mode() do
      :renewal -> {:remove, boosted(damage, fire_ratio(target))}
      :pre_renewal -> {:remove, damage * 2}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @doc """
  Renewal fire damage on a webbed unit: the element-adjusted `damage` was
  computed at `ratio` (the fire-vs-holder multiplier), and the web adds one more
  pre-element base, i.e. `damage / ratio`. Doubles when the ratio is unknown.
  """
  @spec boosted(non_neg_integer(), number() | nil) :: non_neg_integer()
  def boosted(damage, ratio) when is_number(ratio) and ratio > 0,
    do: damage + div(damage * 100, round(ratio * 100))

  def boosted(damage, _ratio), do: damage * 2

  @impl true
  def on_expire(_target, %{state: %{groups: groups}}, _context) do
    Enum.each(groups, &Manager.destroy_async/1)
    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok

  defp fire_ratio({type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, _pid}} ->
        case state.__struct__.to_combatant(state).element do
          {element, level} -> ElementModifiers.get_modifier(:fire, element, level)
          element -> ElementModifiers.get_modifier(:fire, element)
        end

      _unavailable ->
        nil
    end
  end
end
