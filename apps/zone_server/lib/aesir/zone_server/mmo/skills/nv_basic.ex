defmodule Aesir.ZoneServer.Mmo.Skills.NvBasic do
  @moduledoc """
  Basic Skill (NV_BASIC). A pure gating passive: it contributes no stat bonuses
  and has no cast, but its learned level gates basic player actions.

  In rAthena each gated client action checks `pc_checkskill(sd, NV_BASIC)`
  (only when `battle_config.basic_skill_check` is on, and bypassed by
  `SU_BASIC_SKILL` >= 1, which is not yet implemented here):

    | NV_BASIC level | Unlocks        | rAthena source        |
    |----------------|----------------|-----------------------|
    | >= 1           | trade          | clif.cpp:12515        |
    | >= 2           | emotions       | clif.cpp:11636        |
    | >= 3           | sit / stand    | clif.cpp:11739        |
    | >= 4           | create chat room | clif.cpp:12378      |
    | >= 7           | create party   | clif.cpp:13806, 13829 |

  Declaring `@behaviour Skill.Passive` with no callbacks registers the skill as
  passive-capable (matching rAthena's `INF_PASSIVE_SKILL`); the `use Skill`
  `@before_compile` hook injects no-op defaults for every passive channel, which
  is exactly correct since NV_BASIC contributes nothing.

  The `allows_action?/2` helper is the single gate consumers call: it reads the
  player's learned level for this skill and returns `:ok` or
  `{:error, :basic_skill_level}`.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1,
    name: :nv_basic,
    display_name: "Basic Skill",
    max_level: 9,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @typedoc "A basic player action gated by NV_BASIC level."
  @type action :: :trade | :emotion | :sit | :chat_room | :party

  @required_levels %{
    trade: 1,
    emotion: 2,
    sit: 3,
    chat_room: 4,
    party: 7
  }

  @doc """
  Gate for a basic action: returns `:ok` when the player's learned NV_BASIC
  level meets the action's requirement, otherwise `{:error, :basic_skill_level}`.

  `learned_skills` is the player's `%{skill_id => level}` map
  (`PlayerProgression.learned_skills`); an unlearned skill is treated as level 0.
  """
  @spec allows_action?(Learned.t(), action()) :: :ok | {:error, :basic_skill_level}
  def allows_action?(learned_skills, action) when is_map(learned_skills) and is_atom(action) do
    required = Map.fetch!(@required_levels, action)
    level = Learned.learned_level(learned_skills, definition().id)

    if level >= required do
      :ok
    else
      {:error, :basic_skill_level}
    end
  end
end
