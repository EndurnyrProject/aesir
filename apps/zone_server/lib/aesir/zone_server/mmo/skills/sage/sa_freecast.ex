defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast do
  @moduledoc """
  Free Cast (SA_FREECAST). A passive that lets the caster walk and attack while a
  cast is in flight. Walking costs 175 minus 5 per level percent of the normal step
  time and the after-cast act delay is lifted; both are cast-scoped and applied by
  the movement and combat handlers, which read the learned level from `level/1`.

  Renewal shortens the attack motion during a cast to 5 times (level plus 10)
  percent, neutral at level 10. Pre-renewal instead lengthens it towards a 2 s
  ceiling by 50 minus 5 per level percent of the gap (`attack_delay/2`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 278,
    name: :sa_freecast,
    display_name: "Free Cast",
    max_level: 10,
    target_type: :passive,
    damage_kind: :magic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Learned

  @skill_id 278

  @doc """
  The caster's learned Free Cast level, `0` when unlearned.
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
  Walk-speed percentage while a cast is in flight.
  """
  @spec speed_rate(pos_integer()) :: pos_integer()
  def speed_rate(level) when level > 0, do: 175 - 5 * level

  @doc """
  Attack-motion percentage while a cast is in flight in renewal: 5 times (level plus 10).
  attack motion shrinks — a faster swing.
  """
  @spec amotion_rate(pos_integer()) :: pos_integer()
  def amotion_rate(level) when level > 0, do: 5 * (level + 10)

  @doc """
  The attack delay while a cast is in flight. Renewal scales the delay by
  `amotion_rate/1`; pre-renewal lengthens it towards the 2 s ceiling by
  50 minus 5 per level percent of the remaining gap.
  """
  @spec attack_delay(pos_integer(), non_neg_integer()) :: non_neg_integer()
  def attack_delay(level, delay) when level > 0 do
    case GameMode.mode() do
      :renewal -> div(delay * amotion_rate(level), 100)
      :pre_renewal -> delay + div((2_000 - delay) * (50 - 5 * level), 100)
    end
  end
end
