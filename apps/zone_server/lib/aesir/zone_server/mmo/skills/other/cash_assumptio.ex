defmodule Aesir.ZoneServer.Mmo.Skills.Other.CashAssumptio do
  @moduledoc """
  Party Assumptio scroll skill.

  In renewal and pre-renewal, applies the status to eligible party members in
  a 14-cell square, or to self without a party. It has no ordinary support
  skill's SP cost or cast time; recipient refusals are independent.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 691,
    name: :cash_assumptio,
    display_name: "Party Assumptio",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    is_npc: true,
    damage_splash: true,
    splash_radius: 14,
    requires: [],
    status: :sc_assumptio,
    duration: Enum.map(1..5, &(20_000 * &1))

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
          | {:local_effects, Active.caster(), [Active.effect()]}
          | {:error, atom()}
  def cast(caster, target, level, definition),
    do: PartyBuff.cast_cash(caster, target, level, definition)
end
