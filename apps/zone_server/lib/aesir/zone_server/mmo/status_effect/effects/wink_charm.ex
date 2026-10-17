defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WinkCharm do
  @moduledoc """
  Wink of Charm (SC_WINKCHARM).

  A charmed monster may still target and chase the Dancer who charmed it but
  never attacks her, and uses no skills; when the charm ends the monster drops
  its target. Active damage breaks it; a non-player holder keeps it while the
  damage takes no HP, a player does not. Passive HP costs and ticks never break
  it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_winkcharm,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    properties: [:debuff],
    flags: [:remove_on_damaged],
    icon: :dc_winkcharm

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def on_expire({:mob, unit_id}, %StatusEntry{generation: generation}, _context)
      when not is_nil(generation) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} -> MobSession.set_target(pid, nil)
      {:error, :not_found} -> :ok
    end
  end

  def on_expire(_target, _instance, _context), do: :ok
end
