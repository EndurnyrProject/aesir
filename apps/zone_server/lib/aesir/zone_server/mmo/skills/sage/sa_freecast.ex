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

  Attacking falls out of the same move: a cast owns `action_state` only while the
  caster stands still, and `:casting` permits no transition to `:attacking`. Once
  Free Cast moves the caster to `:moving`, the cast is a mere overlay and the
  existing `:moving -> :attacking` edge lets the auto-attack loop run alongside it
  (rAthena `unit.cpp:3230`). A caster without Free Cast never leaves `:casting`
  with a cast in flight, so attacking stays blocked for them with no extra gate.

  This matches the architecture's state diagram, which reaches
  `attacking_while_casting` only from `moving_while_casting`. It is narrower than
  rAthena, where a *standing* Free Caster may also attack; that gap and the
  `unit.cpp:3233` after-cast-delay bypass (Aesir gates attacks on `act_ready?`,
  and Free Cast does not currently bypass it) are left for a fidelity pass.

  ## Walk speed

  `speed_rate/1` is rAthena's `speed_rate = 175 - 5 * pc_checkskill(sd, SA_FREECAST)`
  (`status.cpp:8040-8044`), applied as `speed * speed_rate / 100`. At level 1 a
  step costs 170% of its normal time; at level 10, 125%. rAthena gates this on
  `sd->ud.skilltimer != INVALID_TIMER` — *any* cast in flight, not just one that
  Free Cast itself enabled — so the penalty is cast-scoped, applied at the point
  of use in the step scheduler rather than folded into `walk_speed`. No stat
  recalculation is triggered when a cast starts or ends.

  ## Accepted deviation: no ASPD modification during cast

  rAthena additionally rescales attack motion while casting
  (`status.cpp:6398-6400`):

      #ifdef RENEWAL_ASPD
        amotion = amotion * 5 * (skill_lv + 10) / 100;
      #else
        amotion += (2000 - amotion) * (55 - 5 * (skill_lv + 1)) / 100;
      #endif

  The two branches disagree in direction. Pre-renewal raises `amotion`, slowing
  attacks — the intended cost. The renewal branch *lowers* it at every level
  below 10: at level 1 it yields `amotion * 55 / 100`, a 45% faster attack, so
  learning one level of Free Cast would speed up attacking while casting. That is
  almost certainly a quirk rather than intent, so Aesir applies no ASPD
  modification during cast. Recorded here for a future fidelity pass.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 278,
    name: :sa_freecast,
    display_name: "Free Cast",
    max_level: 10,
    target_type: :passive

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
end
