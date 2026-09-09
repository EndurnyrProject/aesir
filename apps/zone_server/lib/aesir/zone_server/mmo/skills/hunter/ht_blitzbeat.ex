defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlitzbeat do
  @moduledoc """
  Blitz Beat (HT_BLITZBEAT).

  Manual casts require an equipped Falcon and use normal skill cost, range,
  cast-time, and action-delay handling. Automatic casts are queued from the
  confirmed ordinary bow-hit passive seam and reuse the same captured-center
  splash delivery without entering the cast interpreter.

  Renewal: each of the level's hits deals 20 × level + 6 × Steel Crow + 2 × (AGI/2) + 2 × (DEX/10), with a 0.8 s cast plus 0.2 s fixed. Pre-renewal: each hit deals (DEX/10 + INT/2 + 3 × Steel Crow + 40) × 2 regardless of level, with a 1.5 s cast. Both auto-fire on a bow hit with a falcon at LUK × 10/3 + 1 per thousand; a
  pre-renewal automatic cast divides its total between the enemies it hits, while
  renewal gives every target the full total. Vulture's Eye extends the cast range.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 129,
    name: :ht_blitzbeat,
    display_name: "Blitz Beat",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :misc,
    element: :neutral,
    range: 5,
    vulture_range: true,
    hit_count: 1,
    splash_radius: 1,
    sp_cost: [10, 13, 16, 19, 22],
    cast_time: [renewal: List.duplicate(800, 5), pre_renewal: List.duplicate(1500, 5)],
    fixed_cast_time: [renewal: List.duplicate(200, 5), pre_renewal: []],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSteelcrow
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active
  @behaviour Passive

  @steel_crow_id HtSteelcrow.definition().id

  @impl Active
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    if FalconHandler.falcon?(caster), do: :ok, else: {:error, :falcon_not_equipped}
  end

  @impl Active
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, %{position: center}} <- Combat.resolve_combatant(target_id) do
      deliver(caster, center, level, false)
      {:ok, caster}
    end
  end

  @impl Passive
  def after_normal_hit(player_state, hit), do: after_normal_hit(player_state, hit, [])

  @doc false
  @spec after_normal_hit(PlayerState.t(), Passive.hit_context(), keyword()) :: :ok
  def after_normal_hit(
        %PlayerState{stats: %Stats{} = stats} = player_state,
        %{position: center},
        opts
      ) do
    learned_level = Map.get(stats.progression.learned_skills, definition().id, 0)

    effective_level =
      Formulas.auto_blitz_effective_level(learned_level, stats.progression.job_level)

    if automatic_eligible?(player_state, learned_level, effective_level) do
      luk = Stats.get_effective_stat(stats, :luk)
      threshold = Formulas.auto_blitz_chance(luk)
      rng = Keyword.get(opts, :rng, &default_roll/1)

      if rng.(1_000) <= threshold do
        Skill.defer(__MODULE__, %{center: center, skill_level: effective_level}, 0)
      end
    end

    :ok
  end

  def after_normal_hit(_player_state, _hit, _opts), do: :ok

  @doc "Resolves a queued automatic Blitz Beat from the player's live session state."
  @impl Active
  @spec deferred(%{center: {integer(), integer()}, skill_level: pos_integer()}, PlayerState.t()) ::
          :ok
  def deferred(%{center: center, skill_level: level}, %PlayerState{} = caster) do
    deliver(caster, center, level, GameMode.mode() == :pre_renewal)
  end

  defp automatic_eligible?(
         %PlayerState{stats: stats} = player_state,
         learned_level,
         effective_level
       ) do
    learned_level > 0 and effective_level > 0 and FalconHandler.falcon?(player_state) and
      Stats.weapon_type(stats.equipment) == :bow
  end

  defp deliver(%PlayerState{stats: stats} = caster, center, level, split?) do
    steel_crow_level = Map.get(stats.progression.learned_skills, @steel_crow_id, 0)

    caster_stats = %{
      agi: Stats.get_effective_stat(stats, :agi),
      dex: Stats.get_effective_stat(stats, :dex),
      int: Stats.get_effective_stat(stats, :int)
    }

    per_hit_damage = Formulas.blitz_beat_base_damage(level, steel_crow_level, caster_stats)
    total_damage = per_hit_damage * level
    definition = definition()

    Combat.execute_misc_splash(caster, center, definition.splash_radius,
      skill_id: definition.id,
      skill_level: level,
      base_damage: total_damage,
      element: definition.element,
      display_hit_count: level,
      split: split?
    )

    :ok
  end

  defp default_roll(upper), do: :rand.uniform(upper) - 1
end
