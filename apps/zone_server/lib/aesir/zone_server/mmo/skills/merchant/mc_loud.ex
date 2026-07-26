defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McLoud do
  @moduledoc """
  Crazy Uproar (MC_LOUD). Applies SC_LOUD (+4 STR, +30 base ATK) to the caster
  for 5 minutes.

  Re-casting refreshes the buff's duration rather than toggling it off.

  rAthena renewal splashes to party members on the same map (`crazyuproar.cpp:11`,
  `SplashArea: -1`); deferred as no party system exists. This mirrors rAthena's
  fallback for `party_id == 0` and applies to the caster only.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 155,
    name: :mc_loud,
    status: :sc_loud,
    display_name: "Crazy Uproar",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [8],
    cast_time: [1000],
    fixed_cast_time: [300],
    after_cast_delay: [1000],
    cooldown: [30_000],
    quest_skill: true,
    quest_owner_job: :merchant

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    case StatusInterpreter.apply_status(:player, caster_id, :sc_loud, duration: 300_000) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
