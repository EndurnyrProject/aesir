defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline do
  @moduledoc """
  Adrenaline Rush (BS_ADRENALINE) shares an attack-speed and HIT buff with
  nearby party members wielding an axe or mace.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 111,
    name: :bs_adrenaline,
    display_name: "Adrenaline Rush",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 14,
    sp_cost: [20, 23, 26, 29, 32],
    duration: [30_000, 60_000, 90_000, 120_000, 150_000],
    status: :sc_adrenaline,
    require_weapon: [:one_handed_axe, :two_handed_axe, :mace]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    case PartyBuff.apply(caster, :sc_adrenaline, params, definition.splash_radius, fn member ->
           eligible_weapon?(member, definition.require_weapon)
         end) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp eligible_weapon?(%PlayerState{stats: %{equipment: equipment}}, accepted_weapons) do
    Stats.weapon_type(equipment) in accepted_weapons
  end

  defp eligible_weapon?(_player, _accepted_weapons), do: false
end
