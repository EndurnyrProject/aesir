defmodule Aesir.ZoneServer.Mmo.Skills.TfDetoxify do
  @moduledoc """
  Detoxify (TF_DETOXIFY). Removes Poison and Deadly Poison from an ally.

  rAthena: id 53, max level 1, SP 10, range 9.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 53,
    name: :tf_detoxify,
    display_name: "Detoxify",
    max_level: 1,
    target_type: :target_ally,
    range: 9,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @statuses_to_remove [:sc_poison, :sc_dpoison]

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(caster, target, _level, _definition) do
    target_id = Active.resolve_target_id(caster, target)

    Enum.each(@statuses_to_remove, fn status ->
      StatusInterpreter.remove_status(:player, target_id, status)
    end)

    {:ok, caster}
  end
end
