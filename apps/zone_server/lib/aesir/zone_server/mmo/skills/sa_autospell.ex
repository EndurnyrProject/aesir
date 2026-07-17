defmodule Aesir.ZoneServer.Mmo.Skills.SaAutospell do
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

  # The renewal auto-spell list (rAthena `clif_autospell`, clif.cpp:8415-8425):
  # each bolt paired with the autospell level it needs to be *exceeded* -
  # `skill_lv > required` (clif.cpp:8446), never `>=`. Order is rAthena's.
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
  The bolt skill ids offered at `autospell_level`, in rAthena's menu order.

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
  The highest level the armed bolt can proc at: half the autospell level, capped
  by how far the caster has actually learned that bolt (rAthena `skill_autospell`,
  skill.cpp:10740-10751).

  rAthena's Soul Linker branch (`maxlv = 10` for the three basic bolts under
  SC_SPIRIT/SL_SAGE) is skipped - Aesir has no Soul Linker.

  NOTE: the floor of 1 has no rAthena counterpart. There, autospell level 1 makes
  `maxlv = 1/2 = 0`, and the proc then reads `sp_cost[-1]` through `skill_get_lv`
  - an out-of-bounds read (skill.cpp:165). C leaves that undefined; Elixir's
  `Enum.at/2` would quietly return the *level 10* cost instead. A level-0 bolt is
  not a castable thing either way, so the level is floored at 1, which is also
  what rAthena's own `uint16 maxlv = 1` initialiser intends.
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
        selected_id,
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

  # skill_db.yml Duration1 for SA_AUTOSPELL: 120s at level 1 rising 30s a level.
  defp duration(level), do: (90 + 30 * level) * 1_000
end
