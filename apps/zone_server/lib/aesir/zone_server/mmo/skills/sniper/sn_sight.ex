defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnSight do
  @moduledoc """
  True Sight is a 30-second self buff in renewal and pre-renewal, granting
  all-stat, critical, HIT and ATK bonuses. It fails while Quagmired.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 380,
    name: :sn_sight,
    status: :sc_truesight,
    display_name: "True Sight",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    duration: List.duplicate(30_000, 10),
    sp_cost: [20, 20, 25, 25, 30, 30, 35, 35, 40, 40]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    StatusInterpreter.apply_status(:player, id, :sc_truesight,
      val1: level,
      caster_id: id,
      duration: Enum.at(definition.duration, level - 1)
    )

    {:ok, caster}
  end
end
