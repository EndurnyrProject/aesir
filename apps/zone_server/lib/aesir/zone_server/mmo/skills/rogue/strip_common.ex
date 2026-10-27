defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon do
  @moduledoc """
  The Divest family's shared cast, identical in both modes.

  The caster rolls once in per mille: a Divest skill 50 times level plus 50,
  Divest All 50 plus 20 per level never falling below that floor, each plus
  twice the DEX difference. A trap target, having no status, always fails. On
  a monster or homunculus the caster's process drops the slots its Chemical
  Protection covers and starts each remaining piece's status; a player target
  decides the same in its own session, also requiring each piece to be worn.
  The skill's effect shows its result around the target (Divest All only when
  something was stripped) and a player caster is told when nothing was.
  """

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @base_durations [75_000, 90_000, 105_000, 120_000, 135_000]

  @pieces [
    {:right_hand, :sc_stripweapon, :sc_cp_weapon},
    {:left_hand, :sc_stripshield, :sc_cp_shield},
    {:armor, :sc_striparmor, :sc_cp_armor},
    {:head_top, :sc_striphelm, :sc_cp_helm}
  ]

  @typedoc "An equipment slot a Divest skill can strip."
  @type slot :: :right_hand | :left_hand | :armor | :head_top

  @typedoc "`:divest` for the single-piece skills, `:full` for Divest All."
  @type kind :: :divest | :full

  @doc """
  Casts a Divest skill at `{:unit, target}` over `slots`; always `{:ok, caster}`
  once the target resolves, its outcome reported separately.
  """
  @spec cast(struct(), {:unit, term()}, pos_integer(), map(), [slot()], kind()) ::
          {:ok, struct()} | {:error, atom()}
  def cast(caster, {:unit, target_ref}, level, definition, slots, kind) do
    with {:ok, target_pid, target, target_type} <- TargetResolver.resolve(target_ref) do
      outcome = outcome_opts(caster, target, target_ref, level, definition, kind)
      attempt(caster, target_pid, target, target_type, level, slots, outcome)
      {:ok, caster}
    end
  end

  defp attempt(_caster, _pid, _target, :skill_unit, _level, _slots, outcome),
    do: report_outcome(false, outcome)

  defp attempt(caster, target_pid, target, target_type, level, slots, outcome) do
    caster_dex = unit_stats(caster).dex
    target_dex = unit_stats(target).dex

    if __MODULE__.roll_success?(rate(outcome[:kind], level, caster_dex, target_dex)) do
      opts = [
        duration: strip_duration_ms(level, caster_dex, target_dex, target_type),
        caster_id: unit_id(caster),
        source_type: unit_type(caster)
      ]

      strip(target_type, target_pid, unit_id(target), slots, opts, outcome)
    else
      report_outcome(false, outcome)
    end
  end

  @doc "The reference order of the strippable pieces: `{slot, status, protecting status}`."
  @spec pieces() :: [{slot(), atom(), atom()}]
  def pieces, do: @pieces

  @spec strip_success_rate(pos_integer(), integer(), integer()) :: 0..1000
  def strip_success_rate(level, caster_dex, target_dex) do
    (50 * (level + 1) + 2 * (caster_dex - target_dex))
    |> max(0)
    |> min(1_000)
  end

  @doc "Divest All's per-mille rate: its level floor raised by twice the DEX difference."
  @spec fullstrip_success_rate(pos_integer(), integer(), integer()) :: 0..1000
  def fullstrip_success_rate(level, caster_dex, target_dex) do
    floor = 50 + 20 * level
    (floor + 2 * (caster_dex - target_dex)) |> max(floor) |> min(1_000)
  end

  @spec strip_duration_ms(pos_integer(), integer(), integer(), :player | :mob | :homunculus) ::
          pos_integer()
  def strip_duration_ms(level, caster_dex, target_dex, target_type)
      when target_type in [:player, :mob, :homunculus] do
    bonus = max(1, level + 500 * (caster_dex - target_dex))
    Enum.at(@base_durations, level - 1) + bonus + if(target_type == :player, do: 0, else: 15_000)
  end

  @doc "Rolls a per-mille success rate."
  @spec roll_success?(integer()) :: boolean()
  def roll_success?(rate), do: :rand.uniform(1_000) <= rate

  @doc """
  Shows the Divest skill's effect and tells a player caster when nothing was
  stripped. `outcome` carries `skill_id`, `level`, `kind`, `src_id`,
  `target_id`, `origin` (`{map, x, y}` of the target, whose area sees the
  effect; a player target's session replaces it with its live position) and
  `report_to` (the caster's character id, or nil for a monster caster).
  """
  @spec report_outcome(boolean(), keyword()) :: :ok
  def report_outcome(stripped?, outcome) do
    if outcome[:kind] == :divest or stripped?, do: show_effect(stripped?, outcome)

    with false <- stripped?,
         report_to when is_integer(report_to) <- outcome[:report_to],
         do: SkillHandler.report_cast_failure(outcome[:skill_id], report_to, :skill_failed)

    :ok
  end

  defp strip(:player, target_pid, _target_id, slots, opts, outcome),
    do: PlayerSession.strip_equip(target_pid, slots, opts ++ outcome)

  defp strip(target_type, _target_pid, target_id, slots, opts, outcome) do
    applied =
      for {slot, status, protection} <- @pieces,
          slot in slots,
          not StatusStorage.has_status?(target_type, target_id, protection),
          apply_status(target_type, target_id, status, opts) == :ok,
          do: slot

    report_outcome(applied != [], outcome)
  end

  @doc """
  Starts a landed Divest piece's status. The skill already rolled its own
  success, so no generic resistance roll applies.
  """
  @spec apply_status(atom(), integer(), atom(), keyword()) :: :ok | {:error, term()}
  def apply_status(target_type, target_id, status, opts),
    do:
      StatusInterpreter.apply_status(
        target_type,
        target_id,
        status,
        Keyword.put(opts, :bypass_resistance, true)
      )

  defp rate(:divest, level, caster_dex, target_dex),
    do: strip_success_rate(level, caster_dex, target_dex)

  defp rate(:full, level, caster_dex, target_dex),
    do: fullstrip_success_rate(level, caster_dex, target_dex)

  defp outcome_opts(caster, target, target_ref, level, definition, kind) do
    caster_type = unit_type(caster)

    [
      skill_id: definition.id,
      level: level,
      kind: kind,
      src_id: unit_id(caster),
      target_id: target_id(target_ref),
      origin: {target.map_name, target.x, target.y},
      report_to: if(caster_type == :player, do: unit_id(caster))
    ]
  end

  defp target_id({_type, id}), do: id
  defp target_id(id), do: id

  defp show_effect(stripped?, outcome) do
    {map_name, x, y} = outcome[:origin]

    Broadcast.to_in_range(map_name, x, y, Config.view_range(), %SkillEffect{
      skill_id: outcome[:skill_id],
      level: outcome[:level],
      target_id: outcome[:target_id],
      src_id: outcome[:src_id],
      result: if(stripped?, do: 1, else: 0)
    })
  end

  defp unit_stats(unit), do: unit.__struct__.get_stats(unit)
  defp unit_id(unit), do: unit.__struct__.get_unit_id(unit)
  defp unit_type(unit), do: unit.__struct__.get_unit_type(unit)
end
