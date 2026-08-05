defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMaximize do
  @moduledoc """
  Maximize Power (BS_MAXIMIZE).

  Toggles maximum weapon damage. While active, it drains one SP every skill
  level seconds; casting it again ends the effect.
  """

  # Denylist gap: this player-only cast crashes when invoked by a mob.
  use Aesir.ZoneServer.Mmo.Skill,
    id: 114,
    name: :bs_maximize,
    requires: [:player_state],
    display_name: "Maximize Power",
    max_level: 5,
    target_type: :self,
    sp_cost: [10],
    duration: [1_000, 2_000, 3_000, 4_000, 5_000],
    status: :sc_maximizepower

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), :self, pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, _definition) do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_maximizepower,
           tick: level * 1_000
         ) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
