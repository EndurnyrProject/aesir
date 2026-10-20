defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotion do
  @moduledoc """
  Devotion (CR_DEVOTION). Links a same-party ally to the Crusader so the ally's
  damage is redirected to the Crusader: the ally receives the devotion status and
  the Crusader records the ally, paired by a shared link id, for 15 s plus 15 s per
  level.

  Cast gates before SP is charged: the target is a party member other than the
  caster. The guards the reference makes inside its implementation, after the
  requirement is paid, are paid here too: a Crusader-class target, a target more
  than 10 base levels away, and a full devotee set (the Crusader holds at most
  level devotees; a repeat cast refreshes rather than consumes a slot) all spend
  the SP and report the failure. A devotion status the target refuses is not a
  cast failure at all: the Crusader records the link either way. The reach is 7
  to 11 cells by level and 25 SP. Renewal casts in 1.5 s plus 1.5 s fixed;
  pre-renewal in 3 s. Devotion is player-only.
  """

  # NOTE: A bookkeeping failure on the Crusader's link record is reported after
  # the requirement is paid; the reference's devotee array cannot fail there.
  # A dead party target is skipped by the interpreter before the effect runs.
  use Aesir.ZoneServer.Mmo.Skill,
    id: 255,
    name: :cr_devotion,
    requires: [:party],
    status: :sc_devotion,
    display_name: "Devotion",
    max_level: 5,
    target_type: :target_ally,
    range: [7, 8, 9, 10, 11],
    cast_time: [renewal: List.duplicate(1_500, 5), pre_renewal: List.duplicate(3_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(1_500, 5), pre_renewal: []],
    sp_cost: List.duplicate(25, 5),
    duration: [30_000, 45_000, 60_000, 75_000, 90_000],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  # Config constant: the maximum base-level gap between Crusader and devotee.
  @level_difference_limit 10

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
  def validate(
        %PlayerState{character_id: crusader_id} = caster,
        {:unit, devotee_id},
        _level,
        _def
      ) do
    with :ok <- reject_self(crusader_id, devotee_id),
         {:ok, devotee} <- fetch_player(devotee_id) do
      same_party(caster, devotee)
    end
  end

  def validate(%PlayerState{}, _target, _level, _def), do: {:error, :invalid_target}
  def validate(%MobState{}, _target, _level, _def), do: {:error, :mob_cannot_devote}

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
          | {:failed, Active.caster(), atom()}
          | {:error, atom()}
  def cast(
        %PlayerState{character_id: crusader_id} = caster,
        {:unit, devotee_id},
        level,
        definition
      ) do
    with {:ok, devotee} <- fetch_player(devotee_id) do
      case cast_gate(caster, devotee, devotee_id, level) do
        :ok -> apply_devotion(caster, crusader_id, devotee_id, level, definition)
        {:error, reason} -> {:failed, caster, reason}
      end
    end
  end

  @spec reject_self(non_neg_integer(), non_neg_integer()) :: :ok | {:error, :cannot_devote_self}
  defp reject_self(crusader_id, crusader_id), do: {:error, :cannot_devote_self}
  defp reject_self(_crusader_id, _devotee_id), do: :ok

  # The reference refuses the class, the level gap and the slot inside its
  # implementation, after the requirement is paid.
  @spec cast_gate(PlayerState.t(), PlayerState.t(), non_neg_integer(), pos_integer()) ::
          :ok | {:error, atom()}
  defp cast_gate(%PlayerState{character_id: crusader_id} = caster, devotee, devotee_id, level) do
    with :ok <- reject_crusader_class(devotee),
         :ok <- within_level_gap(caster, devotee) do
      slot_available(crusader_id, devotee_id, level)
    end
  end

  # The reference records the Crusader's devotee entry and ignores a refused
  # devotion status, so the cast keeps its requirement either way. Only the
  # Aesir-side link bookkeeping can fail, and it is reported with the payment.
  @spec apply_devotion(
          PlayerState.t(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          Definition.t()
        ) :: {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom()}
  defp apply_devotion(caster, crusader_id, devotee_id, level, definition) do
    link_id = make_ref()
    range = Definition.range_at_level(definition, level)
    duration = Enum.at(definition.duration, level - 1)

    params = [
      caster_id: crusader_id,
      duration: duration,
      state: %{peer: {:player, crusader_id}, link_id: link_id, range: range}
    ]

    StatusInterpreter.apply_status(:player, devotee_id, :sc_devotion, params)

    case DevotedBy.link(crusader_id, devotee_id, link_id) do
      :ok ->
        DevotionMirror.copy_to_devotee(crusader_id, devotee_id)
        {:ok, caster}

      {:error, _reason} ->
        {:failed, caster, :devotion_link_failed}
    end
  end

  @spec fetch_player(non_neg_integer()) :: {:ok, PlayerState.t()} | {:error, :target_not_found}
  defp fetch_player(devotee_id) do
    case UnitRegistry.get_unit(:player, devotee_id) do
      {:ok, {_module, %PlayerState{} = devotee, _pid}} -> {:ok, devotee}
      _gone -> {:error, :target_not_found}
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
