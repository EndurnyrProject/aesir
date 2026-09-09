defmodule Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic do
  @moduledoc """
  Basic Skill (NV_BASIC). A pure gating passive: it contributes no stat bonuses
  and has no cast, but its learned level gates basic player actions.

  Each gated action checks the caster's learned Basic Skill level before it is
  allowed to proceed, regardless of any bypass a summoner-class basic-skill
  substitute would otherwise grant (not implemented here):

    | NV_BASIC level | Unlocks           |
    |-----------------|-------------------|
    | >= 1            | trade             |
    | >= 2            | emotions          |
    | >= 3            | sit / stand       |
    | >= 4            | create chat room  |
    | >= 7            | create/join party |

  Renewal and pre-renewal gate these actions identically: the level
  requirements above, and the set of gated actions, are mode-independent.

  Declaring `@behaviour Skill.Passive` with no callbacks registers the skill as
  a passive with no stat or combat contribution; the `use Skill`
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
