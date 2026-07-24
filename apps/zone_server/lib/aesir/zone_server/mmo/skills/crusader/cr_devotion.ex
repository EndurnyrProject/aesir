defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotion do
  @moduledoc """
  Devotion (CR_DEVOTION).

  Links a same-party ally to the Crusader: the ally receives `sc_devotion` and
  the Crusader records the ally in its single `sc_devoted_by` entry, paired by a
  shared `link_id`. Damage rerouting through the link is a later change; this
  cast only establishes and refreshes the pairing.

  Cast gates (all before SP is charged, in `validate/4`):

    * the target is a living player, and not the caster;
    * the target shares the caster's party;
    * the target is not itself a Crusader-class character;
    * the caster/target base-level gap is within `@level_difference_limit`;
    * a free devotion slot exists - the Crusader holds at most `skill_lv`
      devotees, a repeat cast on an existing devotee refreshing rather than
      consuming a slot.

  Range (7..11 by level) is enforced by the skill interpreter from the
  definition's per-level `range`. Devotion is player-only; a mob caster is
  rejected and the skill is denylisted for the mob executor.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 255,
    name: :cr_devotion,
    status: :sc_devotion,
    display_name: "Devotion",
    max_level: 5,
    target_type: :target_ally,
    range: [7, 8, 9, 10, 11],
    sp_cost: List.duplicate(25, 5),
    duration: [30_000, 60_000, 90_000, 120_000, 150_000]

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  # Config constant: the maximum base-level gap between Crusader and devotee.
  @level_difference_limit 20

  @crusader_classes MapSet.new([
                      :crusader,
                      :crusader2,
                      :paladin,
                      :paladin2,
                      :baby_crusader,
                      :baby_crusader2
                    ])

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{character_id: crusader_id} = caster, {:unit, devotee_id}, level, _def) do
    with :ok <- reject_self(crusader_id, devotee_id),
         {:ok, devotee} <- fetch_living_player(devotee_id),
         :ok <- same_party(caster, devotee),
         :ok <- reject_crusader_class(devotee),
         :ok <- within_level_gap(caster, devotee) do
      slot_available(crusader_id, devotee_id, level)
    end
  end

  def validate(%PlayerState{}, _target, _level, _def), do: {:error, :invalid_target}
  def validate(%MobState{}, _target, _level, _def), do: {:error, :mob_cannot_devote}

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(
        %PlayerState{character_id: crusader_id} = caster,
        {:unit, devotee_id},
        level,
        definition
      ) do
    link_id = make_ref()
    range = Definition.range_at_level(definition, level)
    duration = Enum.at(definition.duration, level - 1)

    params = [
      caster_id: crusader_id,
      duration: duration,
      state: %{peer: {:player, crusader_id}, link_id: link_id, range: range}
    ]

    with :ok <- StatusInterpreter.apply_status(:player, devotee_id, :sc_devotion, params),
         :ok <- DevotedBy.link(crusader_id, devotee_id, link_id) do
      {:ok, caster}
    end
  end

  @spec reject_self(non_neg_integer(), non_neg_integer()) :: :ok | {:error, :cannot_devote_self}
  defp reject_self(crusader_id, crusader_id), do: {:error, :cannot_devote_self}
  defp reject_self(_crusader_id, _devotee_id), do: :ok

  @spec fetch_living_player(non_neg_integer()) ::
          {:ok, PlayerState.t()} | {:error, :target_not_found | :target_dead}
  defp fetch_living_player(devotee_id) do
    case UnitRegistry.get_unit(:player, devotee_id) do
      {:ok, {_module, %PlayerState{} = devotee, _pid}} ->
        if Unit.living?(devotee), do: {:ok, devotee}, else: {:error, :target_dead}

      _ ->
        {:error, :target_not_found}
    end
  end

  @spec same_party(PlayerState.t(), PlayerState.t()) :: :ok | {:error, :not_same_party}
  defp same_party(%PlayerState{party_id: party_id}, %PlayerState{party_id: party_id})
       when party_id != 0,
       do: :ok

  defp same_party(_caster, _devotee), do: {:error, :not_same_party}

  @spec reject_crusader_class(PlayerState.t()) :: :ok | {:error, :target_is_crusader}
  defp reject_crusader_class(%PlayerState{stats: %{progression: %{job_id: job_id}}}) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, name} ->
        if MapSet.member?(@crusader_classes, name),
          do: {:error, :target_is_crusader},
          else: :ok

      _ ->
        :ok
    end
  end

  @spec within_level_gap(PlayerState.t(), PlayerState.t()) :: :ok | {:error, :level_gap_too_large}
  defp within_level_gap(
         %PlayerState{stats: %{progression: %{base_level: caster_level}}},
         %PlayerState{stats: %{progression: %{base_level: devotee_level}}}
       ) do
    if abs(caster_level - devotee_level) <= @level_difference_limit,
      do: :ok,
      else: {:error, :level_gap_too_large}
  end

  @spec slot_available(non_neg_integer(), non_neg_integer(), pos_integer()) ::
          :ok | {:error, :devotion_slots_full}
  defp slot_available(crusader_id, devotee_id, level) do
    if DevotedBy.linked?(crusader_id, devotee_id) or DevotedBy.count(crusader_id) < level,
      do: :ok,
      else: {:error, :devotion_slots_full}
  end
end
