defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCpWeapon do
  @moduledoc "Chemical Protection Weapon (AM_CP_WEAPON)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 234,
    name: :am_cp_weapon,
    status: :sc_cp_weapon,
    display_name: "Chemical Protection Weapon",
    max_level: 5,
    target_type: :target_ally,
    sp_cost: List.duplicate(30, 5),
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

    case StatusInterpreter.apply_status(:player, target_id, :sc_cp_weapon,
           val1: level,
           caster_id: caster_id,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
