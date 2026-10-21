defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaAutospell do
  @moduledoc """
  Hindsight (SA_AUTOSPELL). Offers the caster a menu of the bolts it has
  (learned or granted) and arms the chosen one to fire on weapon hits for 90 s
  plus 30 s per level, for 35 SP. The armed level is capped by the caster's
  level in the bolt; a bolt the caster no longer has when it answers arms
  nothing.

  Renewal: Fire, Cold and Lightning Bolt from level 1, Soul Strike and Fire Ball
  from 4, Earth Spike and Frost Diver from 7, Thunderstorm and Heaven's Drive
  from 10, armed at up to half the Hindsight level (level 0 at Hindsight 1); a
  3 s fixed cast and a 2% per level proc chance.

  Pre-renewal: Napalm Beat from level 1, Cold, Fire and Lightning Bolt from 2,
  Soul Strike from 5, Fire Ball from 8, Frost Diver from 10, each armed at a
  per-bolt level table; a 3 s variable cast and a 5% plus 2% per level proc
  chance.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 279,
    name: :sa_autospell,
    status: :sc_autospell,
    display_name: "Hindsight",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 0,
    sp_cost: List.duplicate(35, 10),
    cast_time: [renewal: [], pre_renewal: List.duplicate(3_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(3_000, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active
  @behaviour Menu

  @napalm_beat 11
  @cold_bolt 14
  @frost_diver 15
  @soul_strike 13
  @fire_ball 17
  @fire_bolt 19
  @lightning_bolt 20
  @basic_bolts [@cold_bolt, @fire_bolt, @lightning_bolt]

  # Each bolt is paired with the auto-spell level that must be strictly
  # exceeded, in each mode's menu order.
  @renewal_bolts [
    {@fire_bolt, 0},
    {@cold_bolt, 0},
    {@lightning_bolt, 0},
    {@soul_strike, 3},
    {@fire_ball, 3},
    {90, 6},
    {@frost_diver, 6},
    {21, 9},
    {91, 9}
  ]

  @classic_bolts [
    {@napalm_beat, 0},
    {@cold_bolt, 1},
    {@fire_bolt, 1},
    {@lightning_bolt, 1},
    {@soul_strike, 4},
    {@fire_ball, 7},
    {@frost_diver, 9}
  ]

  @doc """
  The bolt skill ids offered at `autospell_level`, in the active mode's menu
  order.

  A bolt is offered only when the caster has it (learned or granted, in
  `skills`, a `%{skill_id => level}` map) and the autospell level strictly
  exceeds the bolt's tier requirement.
  """
  @spec eligible_bolts(%{integer() => non_neg_integer()}, pos_integer()) :: [integer()]
  def eligible_bolts(skills, autospell_level) do
    for {skill_id, required} <- bolt_tiers(GameMode.mode()),
        autospell_level > required,
        Map.get(skills, skill_id, 0) > 0,
        do: skill_id
  end

  defp bolt_tiers(:renewal), do: @renewal_bolts
  defp bolt_tiers(:pre_renewal), do: @classic_bolts

  @doc """
  The highest level bolt `bolt_id` can proc at once armed at `autospell_level`,
  capped by the caster's `bolt_level` in it.

  Renewal arms half the auto-spell level, which is 0 at level 1. Pre-renewal
  arms Napalm Beat at 3, the basic bolts at 1, 2 and 3 from auto-spell levels 2,
  3 and 4, Soul Strike at 1, 2 and 3 from 5, 6 and 7, Fire Ball at 1 and 2 from
  8 and 9, and Frost Diver at 1, and nothing else (`nil`). The Soul Linker
  branch is absent because Aesir has no Soul Linker.
  """
  @spec max_level(integer(), non_neg_integer(), pos_integer()) :: non_neg_integer() | nil
  def max_level(bolt_id, bolt_level, autospell_level),
    do: max_level(GameMode.mode(), bolt_id, bolt_level, autospell_level)

  defp max_level(:renewal, _bolt_id, bolt_level, autospell_level),
    do: min(bolt_level, div(autospell_level, 2))

  defp max_level(:pre_renewal, bolt_id, bolt_level, autospell_level) do
    case classic_level(bolt_id, autospell_level) do
      nil -> nil
      classic -> min(bolt_level, classic)
    end
  end

  defp classic_level(@napalm_beat, _autospell_level), do: 3
  defp classic_level(@frost_diver, _autospell_level), do: 1
  defp classic_level(bolt, level) when bolt in @basic_bolts, do: between_1_and(level - 1, 3)
  defp classic_level(@soul_strike, level), do: between_1_and(level - 4, 3)
  defp classic_level(@fire_ball, level), do: between_1_and(level - 7, 2)

  defp classic_level(_bolt, _level), do: nil

  defp between_1_and(level, cap), do: level |> max(1) |> min(cap)

  @impl Active
  def cast(
        %{stats: stats} = caster,
        :self,
        level,
        definition
      ) do
    case eligible_bolts(PlayerStats.effective_skills(stats), level) do
      [] ->
        # The reference sends the menu after the requirement is paid, empty or
        # not, so the cast reports its failure with the cost kept.
        {:failed, caster, :no_eligible_skills}

      entry_ids ->
        offer = %{skill_id: definition.id, kind: :SKILLS, entry_ids: entry_ids, level: level}
        {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @doc """
  Arms the chosen bolt: `sc_autospell` for `90 + 30*level` seconds, carrying the
  bolt, the level it may proc at (`max_level/3`), and the per-hit chance
  (`proc_chance/1`). Nothing is armed, silently, when the caster no longer has
  the bolt or the bolt has no classic level.

  `selected_id` was validated against the offer this skill itself built, so it is
  always a catalogued bolt; a miss here is a broken invariant and crashes.
  """
  @impl Menu
  def on_menu_reply(
        %{stats: stats} = caster,
        %{id: selected_id, extras: _extras},
        level
      ) do
    with bolt_level when bolt_level > 0 <- PlayerStats.skill_level(stats, selected_id),
         armed_level when is_integer(armed_level) <- max_level(selected_id, bolt_level, level) do
      arm(caster, selected_id, armed_level, level)
    else
      _nothing_to_arm -> {:ok, caster}
    end
  end

  defp arm(%{character_id: character_id} = caster, bolt_id, armed_level, level) do
    {:ok, %{name: skill}} = Catalog.by_id(bolt_id)
    state = %{skill: skill, max_level: armed_level, chance: proc_chance(level)}

    case StatusInterpreter.apply_status(:player, character_id, :sc_autospell,
           val1: level,
           duration: duration(level),
           caster_id: character_id,
           state: state
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  # Duration starts at 120 seconds and rises by 30 seconds per level.
  defp duration(level), do: (90 + 30 * level) * 1_000

  @doc "The per-hit proc chance in percent: 2 per level in renewal, 5 plus 2 per level in classic."
  @spec proc_chance(pos_integer()) :: pos_integer()
  def proc_chance(level) do
    case GameMode.mode() do
      :renewal -> 2 * level
      :pre_renewal -> 5 + 2 * level
    end
  end
end
