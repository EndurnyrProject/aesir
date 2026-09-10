defmodule Aesir.ZoneServer.Mmo.Skills.Sage.Endow do
  @moduledoc """
  Shared cast and success roll for the four Sage weapon endows.

  Renewal endows always succeed. Pre-renewal endows succeed 60% plus 10% per level
  of the time; a failure keeps the cast's costs and applies nothing.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc "Applies `status` to the resolved target for the level's duration unless the classic roll fails."
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t(), atom()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition, status) do
    target_id = Active.resolve_target_id(caster, target)

    if classic_failure?(level) do
      {:ok, caster}
    else
      with :ok <-
             StatusInterpreter.apply_status(:player, target_id, status,
               val1: level,
               caster_id: caster_id,
               duration: Enum.at(definition.duration, level - 1)
             ) do
        {:ok, caster}
      end
    end
  end

  @doc """
  Whether this classic endow cast fails its success roll; never in renewal.
  `roll` draws the percentile (1..100) and defaults to the random generator.
  """
  @spec classic_failure?(pos_integer(), (pos_integer() -> pos_integer())) :: boolean()
  def classic_failure?(level, roll \\ &:rand.uniform/1) do
    GameMode.mode() == :pre_renewal and roll.(100) > 60 + 10 * level
  end
end
