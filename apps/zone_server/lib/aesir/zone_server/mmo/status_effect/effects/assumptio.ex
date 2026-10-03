defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Assumptio do
  @moduledoc """
  Assumptio (SC_ASSUMPTIO). `val1` is the skill level.

  Renewal: the holder gains `50 * level` hard DEF, and Heal cast on the holder
  gains `2 * level` percent in Heal's additive bonus pool (read by the Heal
  formula, not here). Incoming damage is otherwise untouched, and Kyrie Eleison
  coexists with it.

  Pre-renewal: every incoming hit (physical, magic, or misc) is halved, or cut
  to two thirds on a PvP or GvG map. Status-driven damage (poison ticks, HP
  costs) is not an attack and stays whole. No DEF is granted. Kyrie Eleison and
  Assumptio end each other on application.

  In both modes it is dispellable on players, while Dispel spares it on mobs,
  and mobs can grant it to boss allies. Deviations: the status shows the
  renewal icon in both modes (status icons are static per definition), and
  Kaite exclusivity and Hermode removal are not modelled because neither skill
  exists.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_assumptio,
    no_dispel: false,
    bypass_boss_immunity: true,
    properties: [:buff],
    calc_flags: [:def],
    end_on_start: [renewal: [], pre_renewal: [:sc_kyrie]],
    icon: :assumptio2

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{def: 50 * instance.val1}
      :pre_renewal -> %{}
    end
  end

  @impl true
  def absorb_damage(_target, instance, %{status_tick?: true, damage: damage}, _context),
    do: {:ok, damage, instance}

  def absorb_damage(target, instance, %{damage: damage}, _context) do
    case GameMode.mode() do
      :renewal -> {:ok, damage, instance}
      :pre_renewal -> {:ok, reduce(damage, versus_map?(target)), instance}
    end
  end

  defp reduce(damage, true), do: div(damage * 2, 3)
  defp reduce(damage, false), do: div(damage, 2)

  defp versus_map?({unit_type, unit_id}) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {_x, _y, map}} -> MapFlags.get(map, :pvp) or MapFlags.get(map, :gvg)
      {:error, :not_found} -> false
    end
  end
end
