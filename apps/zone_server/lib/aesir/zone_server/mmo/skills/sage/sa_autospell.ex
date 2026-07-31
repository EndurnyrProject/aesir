defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaAutospell do
  @moduledoc """
  Auto Spell (SA_AUTOSPELL). Offers the caster a menu of bolts it has learned and
  arms the chosen one to proc on its weapon hits (`:sc_autospell`).
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
    fixed_cast_time: List.duplicate(3_000, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active
  @behaviour Menu

  # Each bolt is paired with the auto-spell level that must be strictly exceeded.
  # The displayed order follows the canonical Renewal menu.
  @bolt_tiers [
    {19, 0},
    {14, 0},
    {20, 0},
    {13, 3},
    {17, 3},
    {90, 6},
    {15, 6},
    {21, 9},
    {91, 9}
  ]

  @doc """
  The bolt skill ids offered at `autospell_level`, in canonical menu order.

  A bolt is offered only when the caster has learned it and the autospell level
  strictly exceeds the bolt's tier requirement.
  """
  @spec eligible_bolts(Learned.t(), pos_integer()) :: [integer()]
  def eligible_bolts(learned, autospell_level) do
    for {skill_id, required} <- @bolt_tiers,
        autospell_level > required,
        Learned.learned_level(learned, skill_id) > 0,
        do: skill_id
  end

  @doc """
  The highest level the armed bolt can proc at: half the auto-spell level, capped
  by how far the caster has actually learned that bolt.

  The Soul Linker branch for the three basic bolts is skipped because Aesir has
  no Soul Linker. The result is floored at 1 because a level-zero bolt is not
  castable and would otherwise select an invalid SP cost.
  """
  @spec max_level(non_neg_integer(), pos_integer()) :: pos_integer()
  def max_level(learned_level, autospell_level) do
    max(1, min(learned_level, div(autospell_level, 2)))
  end

  @impl Active
  def cast(
        %{stats: %{progression: %{learned_skills: learned}}} = caster,
        :self,
        level,
        definition
      ) do
    case eligible_bolts(learned, level) do
      [] ->
        {:error, :no_eligible_skills}

      entry_ids ->
        offer = %{skill_id: definition.id, kind: :SKILLS, entry_ids: entry_ids, level: level}
        {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @doc """
  Arms the chosen bolt: `sc_autospell` for `90 + 30*level` seconds, carrying the
  bolt, the level it may proc at, and the `2*level`% per-hit chance.

  `selected_id` was validated against the offer this skill itself built, so it is
  always a catalogued bolt; a miss here is a broken invariant and crashes.
  """
  @impl Menu
  def on_menu_reply(
        %{character_id: character_id, stats: %{progression: %{learned_skills: learned}}} = caster,
        %{id: selected_id, extras: _extras},
        level
      ) do
    {:ok, %{name: skill}} = Catalog.by_id(selected_id)

    state = %{
      skill: skill,
      max_level: max_level(Learned.learned_level(learned, selected_id), level),
      chance: 2 * level
    }

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
end
