defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Cost do
  @moduledoc """
  Resolves ordinary performance SP costs before applying Adaptation.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @spec resolve(map(), Definition.t(), pos_integer(), non_neg_integer() | nil) :: Cost.t()
  def resolve(game_state, definition, level, raw_base \\ nil) do
    sp = Cost.resolve_sp(game_state, definition, level, raw_base)

    sp =
      if StatusStorage.has_status?(:player, game_state.character_id, :sc_adaptation) do
        sp - div(sp * 20, 100)
      else
        sp
      end

    Cost.from_definition(game_state, definition, level, sp: sp)
  end
end
