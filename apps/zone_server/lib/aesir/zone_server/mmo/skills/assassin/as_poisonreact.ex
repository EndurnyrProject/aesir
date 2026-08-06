defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsPoisonreact do
  @moduledoc """
  Poison React (AS_POISONREACT) arms a reactive counter stance on the caster.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 139,
    name: :as_poisonreact,
    status: :sc_poisonreact,
    display_name: "Poison React",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [25, 30, 35, 40, 45, 50, 55, 60, 45, 45],
    duration: [
      20_000,
      25_000,
      30_000,
      35_000,
      40_000,
      45_000,
      50_000,
      55_000,
      60_000,
      60_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: caster_id} = caster, :self, level, definition) do
    case StatusInterpreter.apply_status(:player, caster_id, :sc_poisonreact,
           val1: level,
           duration: Enum.at(definition.duration, level - 1),
           caster_id: caster_id,
           source_type: :player
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}
end
