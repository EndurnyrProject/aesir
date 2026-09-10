defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Cost do
  @moduledoc """
  Resolves ordinary performance SP costs before applying Adaptation.

  Renewal: an active Adaptation status cuts the resolved song cost by 20%.
  Pre-renewal: Adaptation has no cost effect; the resolved cost stands.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @spec resolve(map(), Definition.t(), pos_integer(), non_neg_integer() | nil) :: Cost.t()
  def resolve(game_state, definition, level, raw_base \\ nil) do
    sp = Cost.resolve_sp(game_state, definition, level, raw_base)

    sp =
      if adaptation_discount?(game_state) do
        sp - div(sp * 20, 100)
      else
        sp
      end

    Cost.from_definition(game_state, definition, level, sp: sp)
  end

  defp adaptation_discount?(game_state) do
    GameMode.mode() == :renewal and
      StatusStorage.has_status?(:player, game_state.character_id, :sc_adaptation)
  end
end
