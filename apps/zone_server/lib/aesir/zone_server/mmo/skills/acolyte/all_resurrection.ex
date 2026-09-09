defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection do
  @moduledoc """
  Resurrection (`ALL_RESURRECTION`), reviving a player corpse or attacking a
  living undead enemy. A revived player comes back with 10/30/50/80 percent HP
  by level. A target counts as undead by race or by an undead defence element.

  In both modes, player-corpse revival is unavailable on siege ground while the
  separate living-undead attack remains available.

  Renewal: cast times of 4.8/3.2/1.6/0 seconds with a fixed 1.2/0.8/0.4/0 on
  top, and an after-cast delay that grows with level. The instant-death roll
  leans on the target's missing health; a surviving target takes the caster's
  magic attack scaled to the skill level in percent.

  Pre-renewal: a single cast time of 6/4/2/0 seconds with no fixed component,
  the same after-cast delay ladder. The instant-death roll counts the skill level
  double over a narrower health span, and a surviving target takes a flat amount
  built from the caster's base level and INT that ignores magic attack entirely.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 54,
    name: :all_resurrection,
    display_name: "Resurrection",
    max_level: 4,
    target_type: :target_resurrection,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    element: :holy,
    cast_time: [renewal: [4_800, 3_200, 1_600, 0], pre_renewal: [6_000, 4_000, 2_000, 0]],
    fixed_cast_time: [renewal: [1_200, 800, 400, 0], pre_renewal: []],
    after_cast_delay: [0, 1_000, 2_000, 3_000],
    sp_cost: List.duplicate(60, 4),
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection.Damage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  # NOTE: Normal-PvE only until Aesir has WoE, BG, PvP-score, Hell Power, and
  # resurrection-config concepts; add their rAthena gates/options here then.
  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _target_pid, target_state, unit_type} <- TargetResolver.resolve(target_id) do
      cond do
        unit_type == :player and Unit.corpse?(target_state) ->
          ensure_revival_allowed(target_state)

        Unit.living?(target_state) and undead?(target_state) ->
          :ok

        true ->
          {:error, :invalid_target}
      end
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, target_pid, target_state, unit_type} <- TargetResolver.resolve(target_id),
         target_kind <- target_kind(unit_type, target_state),
         :ok <-
           apply_resurrection(
             target_kind,
             caster,
             caster_id,
             target_id,
             target_pid,
             target_state,
             level,
             definition
           ) do
      {:ok, caster}
    end
  end

  defp target_kind(:player, target_state) do
    if Unit.corpse?(target_state), do: :corpse, else: living_undead_kind(target_state)
  end

  defp target_kind(_unit_type, target_state), do: living_undead_kind(target_state)

  defp living_undead_kind(target_state) do
    if Unit.living?(target_state) and undead?(target_state), do: :undead, else: :invalid
  end

  defp apply_resurrection(
         :corpse,
         _caster,
         caster_id,
         _target_id,
         target_pid,
         target_state,
         level,
         _definition
       ) do
    with :ok <- ensure_revival_allowed(target_state) do
      PlayerSession.resurrect(target_pid, caster_id, hp_percent(level))
    end
  end

  defp apply_resurrection(
         :undead,
         caster,
         _caster_id,
         target_id,
         _target_pid,
         target_state,
         level,
         definition
       ) do
    with {:ok, _ref} <- attack_undead(caster, target_id, target_state, level, definition) do
      :ok
    end
  end

  defp apply_resurrection(
         :invalid,
         _caster,
         _caster_id,
         _target_id,
         _target_pid,
         _target_state,
         _level,
         _definition
       ),
       do: {:error, :invalid_target}

  defp ensure_revival_allowed(%{map_name: map_name}) do
    if Rules.ground?(map_name), do: {:error, :invalid_target}, else: :ok
  end

  defp hp_percent(level), do: Enum.at([10, 30, 50, 80], level - 1)

  defp attack_undead(caster, target_id, target_state, level, definition) do
    caster_stats = PlayerState.get_stats(caster)
    target_stats = target_state.__struct__.get_stats(target_state)
    mode = GameMode.mode()

    if instant_kill?(mode, target_state, caster_stats, target_stats, level) do
      Combat.execute_magic_attack(caster, target_id,
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 0,
        bonus_matk: target_stats.hp,
        element: definition.element,
        skip_range: true
      )
    else
      hit =
        Damage.undead_hit(mode, %{
          level: level,
          base_level: caster_stats.base_level,
          int: caster_stats.int
        })

      Combat.execute_magic_attack(
        caster,
        target_id,
        Keyword.merge(
          [
            skill_id: definition.id,
            skill_level: level,
            element: definition.element,
            skip_range: true
          ],
          hit
        )
      )
    end
  end

  defp instant_kill?(mode, target_state, caster_stats, target_stats, level) do
    combatant = target_state.__struct__.to_combatant(target_state)

    Map.get(combatant, :class, :normal) != :boss and
      :rand.uniform(1_000) - 1 < instant_kill_score(mode, caster_stats, target_stats, level)
  end

  @doc false
  @spec instant_kill_score(GameMode.t(), map(), map(), pos_integer()) :: non_neg_integer()
  def instant_kill_score(mode, caster_stats, target_stats, level) do
    Damage.instant_kill_score(mode, %{
      level: level,
      luk: caster_stats.luk,
      int: caster_stats.int,
      base_level: caster_stats.base_level,
      target_hp: target_stats.hp,
      target_max_hp: target_stats.max_hp
    })
  end

  defp undead?(target_state) do
    RaceModifiers.undead_target?(target_state.__struct__.to_combatant(target_state))
  end
end
