defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline do
  @moduledoc """
  Adrenaline Rush (BS_ADRENALINE). Shares an attack-speed buff with the caster and
  every same-map party member wielding an axe or mace within the default 14-cell
  area, for 30 s per level and 20 to 32 SP; a Hilt Binding caster adds 10% duration.

  Renewal: a flat +7 attack speed plus 5 plus 3 per level HIT for everyone.
  Pre-renewal: a 30 percent attack speed rate for the caster and 20 percent for
  recipients (the status reads who cast it), with no HIT.
  """

  # Requirement gap closed: this player-only cast crashes when invoked by a mob.
  use Aesir.ZoneServer.Mmo.Skill,
    id: 111,
    name: :bs_adrenaline,
    requires: [:player_state],
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
      duration: PartyBuff.duration_for_caster(caster, Enum.at(definition.duration, level - 1))
    ]

    with :ok <-
           PartyBuff.apply(caster, :sc_adrenaline, params, definition.splash_radius, fn member ->
             eligible_weapon?(member, definition.require_weapon)
           end) do
      {:ok, caster}
    end
  end

  defp eligible_weapon?(%PlayerState{stats: %{equipment: equipment}}, accepted_weapons) do
    Stats.weapon_type(equipment) in accepted_weapons
  end

  defp eligible_weapon?(_player, _accepted_weapons), do: false
end
