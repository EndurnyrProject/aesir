defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline2 do
  @moduledoc """
  Advanced Adrenaline Rush (BS_ADRENALINE2) shares an attack-speed buff with
  nearby party members wielding a supported weapon. Casting remains unavailable
  until its external empowerment prerequisite is implemented.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline2

  @accepted_weapons Adrenaline2.metadata().require_weapon

  use Aesir.ZoneServer.Mmo.Skill,
    id: 459,
    name: :bs_adrenaline2,
    display_name: "Advanced Adrenaline Rush",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 14,
    sp_cost: [64],
    duration: [150_000],
    status: :sc_adrenaline2,
    require_weapon: @accepted_weapons,
    quest_skill: true,
    quest_owner_job: :blacksmith

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, _target, _level, _definition), do: empowerment_prerequisite(caster)

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    case PartyBuff.apply(caster, :sc_adrenaline2, params, definition.splash_radius, fn member ->
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

  defp empowerment_prerequisite(_caster), do: {:error, :missing_adrenaline_empowerment}
end
