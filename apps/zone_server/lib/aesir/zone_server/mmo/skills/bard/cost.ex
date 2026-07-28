defmodule Aesir.ZoneServer.Mmo.Skills.Bard.Cost do
  @moduledoc """
  Resolves ordinary Bard SP costs before applying Adaptation to eligible skills.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @adaptation_skills MapSet.new([317, 319, 320, 321, 322])

  @spec resolve(map(), Definition.t(), pos_integer(), non_neg_integer() | nil) :: Cost.t()
  def resolve(game_state, definition, level, raw_base \\ nil) do
    sp = Cost.resolve_sp(game_state, definition, level, raw_base)
    sp = if adapted?(game_state, definition.id), do: sp - div(sp * 20, 100), else: sp

    Cost.from_definition(game_state, definition, level, sp: sp)
  end

  defp adapted?(game_state, skill_id) do
    MapSet.member?(@adaptation_skills, skill_id) and
      StatusStorage.has_status?(:player, game_state.character_id, :sc_adaptation)
  end
end
