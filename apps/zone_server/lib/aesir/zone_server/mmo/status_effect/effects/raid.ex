defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Raid do
  @moduledoc """
  Raid debuff (SC_RAID), granted by renewal Sightless Mind for 10 s.

  Renewal: in the common damage stage, right after Lex Aeterna, every attack on
  the holder gains 30% (15% against a boss-class holder), the added amount
  truncated. The damage step does not exist in pre-renewal, where the skill
  never grants the status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_raid,
    no_dispel: true,
    no_clear_buff: [renewal: false, pre_renewal: true],
    properties: [:debuff],
    duration: 10_000,
    icon: :raid

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def absorb_damage({unit_type, unit_id}, instance, %{damage: damage}, _context) do
    case GameMode.mode() do
      :renewal -> {:ok, damage + div(damage * amplification(unit_type, unit_id), 100), instance}
      :pre_renewal -> {:ok, damage, instance}
    end
  end

  defp amplification(unit_type, unit_id) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, %{boss_flag: true}} -> 15
      _ -> 30
    end
  end
end
