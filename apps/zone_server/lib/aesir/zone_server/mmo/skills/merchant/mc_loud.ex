defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McLoud do
  @moduledoc """
  Crazy Uproar (MC_LOUD). Applies SC_LOUD to the caster for 5 minutes.

  Re-casting refreshes the buff's duration rather than toggling it off. In
  renewal the buff is shared with every online party member within the default
  area size (14 cells) on the caster's map through `PartyBuff.apply/4`; a caster
  with no party buffs only themself.

  Renewal: 1 s variable and 0.3 s fixed cast, 1 s after-cast delay, 30 s cooldown, and the five-minute buff (+4 STR, +30 base ATK) is shared with party members within 14 cells on the same map. Pre-renewal: instant cast with no delay or cooldown, the buff is +4 STR only, and it applies to the caster alone.
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
    splash_radius: [renewal: 14, pre_renewal: 0],
    sp_cost: [8],
    cast_time: [renewal: [1000], pre_renewal: [0]],
    fixed_cast_time: [renewal: [300], pre_renewal: [0]],
    after_cast_delay: [renewal: [1000], pre_renewal: [0]],
    cooldown: [renewal: [30_000], pre_renewal: [0]],
    quest_skill: true,
    quest_owner_job: :merchant

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @duration_ms 300_000

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, _level, definition) do
    result =
      case GameMode.mode() do
        :renewal ->
          PartyBuff.apply(caster, :sc_loud, [duration: @duration_ms], definition.splash_radius)

        :pre_renewal ->
          StatusInterpreter.apply_status(:player, caster_id, :sc_loud, duration: @duration_ms)
      end

    case result do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
