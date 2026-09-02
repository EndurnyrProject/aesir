defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast do
  @moduledoc """
  Free Cast (SA_FREECAST). Lets the caster walk and attack while a cast is in
  flight, at the cost of walk speed.

  A passive with no `Skill.Passive` callbacks: it grants no stat bonus, so there
  is nothing for the stat pipeline to fold in. The behavior lives in the cast
  machine, which reads the learned level through `level/1`:
  `Player.Handlers.MovementHandler` keeps the `casting` descriptor across the
  `:casting -> :moving` transition instead of hard-cancelling the cast, and scales
  each walk step by `speed_rate/1`.

  ## Attacking while casting

  A Free Caster may attack with a cast in flight, standing or moving (rAthena
  `unit.cpp:3230`). The cast is an overlay on either action state: `:casting`
  now permits `:casting -> :attacking` and `CombatActionHandler` takes it only
  for a caster who knows Free Cast, keeping the `casting` descriptor across the
  transition so the cast keeps running; a moving caster is already in `:moving`
  and uses the existing `:moving -> :attacking` edge. A caster without Free Cast
  stays blocked — `CombatActionHandler` refuses the swing while in `:casting`.

  Free Cast also lifts the after-cast act delay for its owner's attacks (rAthena
  `unit.cpp:3233`, a second Free Cast gate): `CombatActionHandler` treats
  `act_ready?` as satisfied whenever Free Cast is known.

  ## Walk speed

  `speed_rate/1` is rAthena's `speed_rate = 175 - 5 * pc_checkskill(sd, SA_FREECAST)`
  (`status.cpp:8040-8044`), applied as `speed * speed_rate / 100`. At level 1 a
  step costs 170% of its normal time; at level 10, 125%. rAthena gates this on
  `sd->ud.skilltimer != INVALID_TIMER` — *any* cast in flight, not just one that
  Free Cast itself enabled — so the penalty is cast-scoped, applied at the point
  of use in the step scheduler rather than folded into `walk_speed`. No stat
  recalculation is triggered when a cast starts or ends.

  ## Attack motion during cast

  While a cast is in flight the attack motion is rescaled by the renewal factor
  `amotion * 5 * (level + 10) / 100` (`status.cpp:6398-6400`), exposed as
  `amotion_rate/1`. It is neutral (100%) at level 10 and *faster* below it — at
  level 1 an attack takes 55% of its normal time. The direction is unintuitive
  (the pre-renewal branch instead slows attacks), but it is the renewal formula,
  applied at the point of use in `CombatActionHandler.compute_attack_delay/1`
  and scoped to the cast just like the walk penalty.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 278,
    name: :sa_freecast,
    display_name: "Free Cast",
    max_level: 10,
    target_type: :passive,
    damage_kind: :magic

  alias Aesir.ZoneServer.Mmo.Skill.Learned

  @skill_id 278

  @doc """
  The caster's learned Free Cast level, `0` when unlearned (rAthena `pc_checkskill`).
  """
  @spec level(map()) :: non_neg_integer()
  def level(%{stats: %{progression: %{learned_skills: learned}}}) do
    Learned.learned_level(learned, @skill_id)
  end

  def level(_game_state), do: 0

  @doc """
  Whether the caster knows Free Cast at all.
  """
  @spec known?(map()) :: boolean()
  def known?(game_state), do: level(game_state) > 0

  @doc """
  Walk-speed percentage while a cast is in flight (rAthena `speed_rate`).
  """
  @spec speed_rate(pos_integer()) :: pos_integer()
  def speed_rate(level) when level > 0, do: 175 - 5 * level

  @doc """
  Attack-motion percentage while a cast is in flight (rAthena renewal
  `amotion * 5 * (level + 10) / 100`). Neutral (100) at level 10; below it the
  attack motion shrinks — a faster swing.
  """
  @spec amotion_rate(pos_integer()) :: pos_integer()
  def amotion_rate(level) when level > 0, do: 5 * (level + 10)
end
