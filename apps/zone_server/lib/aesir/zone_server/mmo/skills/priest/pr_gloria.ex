defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrGloria do
  @moduledoc """
  Gloria (PR_GLORIA), the Renewal party-wide LUK buff.

  Self-cast: grants the caster and every eligible nearby party member a flat LUK
  bonus for the skill's duration.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 75,
    name: :pr_gloria,
    status: :sc_gloria,
    display_name: "Gloria",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 18,
    cast_time: List.duplicate(0, 5),
    fixed_cast_time: List.duplicate(0, 5),
    after_cast_delay: List.duplicate(2_000, 5),
    duration: [10_000, 15_000, 20_000, 25_000, 30_000],
    sp_cost: List.duplicate(20, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    case PartyBuff.apply(caster, :sc_gloria, params, definition.splash_radius) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
