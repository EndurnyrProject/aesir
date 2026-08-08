defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Raid do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_raid,
    no_dispel: true,
    properties: [:debuff],
    duration: 10_000,
    icon: :raid

  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def absorb_damage({unit_type, unit_id}, instance, %{damage: damage}, _context)
      when damage > 0 do
    {:ok, damage + div(damage * amplification(unit_type, unit_id), 100), instance}
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  defp amplification(unit_type, unit_id) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, %{boss_flag: true}} -> 15
      _ -> 30
    end
  end
end
