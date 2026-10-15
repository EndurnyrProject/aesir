defmodule Aesir.ZoneServer.Mmo.Combat.SkillRange do
  @moduledoc """
  The range class of a skill hit: whether it lands as a short (melee) or a long
  (ranged) attack.

  Every weapon, magic and misc skill hit takes one class, which feeds every
  range-gated effect: equipment procs and range-flagged bonuses, Safety Wall and
  Pneuma, the near/long card families and the kill-reward attack type. Normal
  attacks keep their own attack-range rule and are not classified here.

  The rules, in order:

  1. A trap skill is always short (classic Fire Pillar is a trap too).
  2. A monster's Arrow Shower and Bomb are short. Renewal Brandish Spear is long
     for every caster, and Spiral Pierce for every caster but a player.
  3. A monster, pet or homunculus is short within 3 cells (Chebyshev) of its
     target and long beyond.
  4. Any other caster is short when the skill's server range is below 4 cells
     (`server_range/3`), long otherwise.

  A non-player without a known position falls through to rule 4.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @typedoc "Whether a hit lands at melee or ranged distance."
  @type range :: :short | :long

  # Arrow Shower and Bomb cast by a monster.
  @monster_short_skills [47, 229]
  @brandish_spear 57
  @spiral_pierce 397
  @distance_units [:mob, :pet, :homunculus]
  @max_server_range 14
  @non_player_self_range 9

  @doc """
  Classifies a skill hit by `attacker` on `target` with `skill_id` at
  `skill_level`, following the rules in the moduledoc.
  """
  @spec classify(map(), map(), integer(), non_neg_integer()) :: range()
  def classify(attacker, target, skill_id, skill_level) do
    cond do
      override = override(attacker, skill_id) ->
        override

      attacker.unit_type in @distance_units ->
        by_distance(attacker, target, skill_id, skill_level)

      true ->
        by_server_range(attacker, skill_id, skill_level)
    end
  end

  defp override(attacker, skill_id) do
    cond do
      trap_skill?(skill_id) -> :short
      attacker.unit_type == :mob and skill_id in @monster_short_skills -> :short
      skill_id == @brandish_spear and GameMode.mode() == :renewal -> :long
      skill_id == @spiral_pierce and attacker.unit_type != :player -> :long
      true -> nil
    end
  end

  @doc """
  The server-side range of a skill at `skill_level` for `attacker`, in cells.

  The database range counts its absolute value (a negative range does not ask
  for the weapon's reach on this server) and is capped at 14 cells. A player
  then adds their Vulture's Eye level to a skill that trains with it. A
  non-player whose skill has no range reaches 9 cells. An unknown skill has no
  range.
  """
  @spec server_range(map(), integer(), non_neg_integer()) :: non_neg_integer()
  def server_range(attacker, skill_id, skill_level) do
    range =
      case Catalog.by_id(skill_id) do
        {:ok, definition} ->
          database_range(definition, skill_level) + vulture_bonus(attacker, definition)

        :error ->
          0
      end

    if range == 0 and attacker.unit_type != :player, do: @non_player_self_range, else: range
  end

  @doc """
  A skill's database range at `skill_level` as the server counts it: its
  absolute value, capped at 14 cells. Caster bonuses such as Vulture's Eye come
  on top.
  """
  @spec database_range(Definition.t(), non_neg_integer()) :: non_neg_integer()
  def database_range(definition, skill_level) do
    definition
    |> Definition.range_at_level(skill_level)
    |> abs()
    |> min(@max_server_range)
  end

  defp trap_skill?(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, %Definition{is_trap: is_trap}} -> is_trap
      :error -> false
    end
  end

  defp by_distance(%{position: {x1, y1}}, %{position: {x2, y2}}, _skill_id, _skill_level) do
    if Geometry.chebyshev_distance(x1, y1, x2, y2) <= 3, do: :short, else: :long
  end

  defp by_distance(attacker, _target, skill_id, skill_level),
    do: by_server_range(attacker, skill_id, skill_level)

  defp by_server_range(attacker, skill_id, skill_level) do
    if server_range(attacker, skill_id, skill_level) < 4, do: :short, else: :long
  end

  defp vulture_bonus(%{unit_type: :player} = attacker, %Definition{vulture_range: true}),
    do: Map.get(attacker, :vulture_eye_level, 0)

  defp vulture_bonus(_attacker, _definition), do: 0
end
