defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CloseConfine2 do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_closeconfine2,
    no_dispel: true,
    no_save: true,
    remove_on_map_change: true,
    properties: [:prevents_movement],
    flags: [:no_move],
    tick_interval: 1_000,
    duration: 10_000,
    icon: :rg_cconfine_m

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def on_tick(_target, %StatusEntry{val2: peer_id} = instance, _context) do
    if alive?(peer_id), do: {:ok, instance}, else: :remove
  end

  defp alive?(unit_id) do
    Enum.any?([:player, :mob], fn unit_type ->
      case UnitRegistry.get_unit(unit_type, unit_id) do
        {:ok, {_module, state, _pid}} -> Unit.living?(state)
        _ -> false
      end
    end)
  end
end
