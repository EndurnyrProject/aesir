defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCpShield do
  @moduledoc "Chemical Protection Shield (AM_CP_SHIELD)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 235,
    name: :am_cp_shield,
    status: :sc_cp_shield,
    display_name: "Chemical Protection Shield",
    max_level: 5,
    target_type: :target_ally,
    sp_cost: List.duplicate(25, 5),
    item_cost: [%{id: 7139, amount: 1}],
    duration: [120_000, 240_000, 360_000, 480_000, 600_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)

    case StatusInterpreter.apply_status(:player, target_id, :sc_cp_shield,
           val1: level,
           caster_id: caster_id,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
