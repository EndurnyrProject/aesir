defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgMarionette do
  @moduledoc """
  Marionette Control links one party member or the caster's own Homunculus
  within seven cells in both modes.

  The master loses frozen halves of each base primary stat and one thousand
  MaxHP; the puppet gains those halves, capped against their total stats at
  ninety-nine. Both halves tick until removed or the pair separates. Recasting
  on the current puppet ends the link.

  Self, non-party, a foreign Homunculus and a caster already wearing a puppet's
  half are refused before the cost. The same-sex performer, cursed and
  quagmired refusals happen inside the implementation, after the requirement is
  paid, and spare the skill's items, as does a cast onto a participant of
  another link. A dead target ends the use before this implementation runs. A
  refused half of the pair is ignored; the applied half retires on its own tick
  when its peer is missing.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 396,
    no_target_self: true,
    name: :cg_marionette,
    display_name: "Marionette Control",
    max_level: 1,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 7,
    sp_cost: [100],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @primary_stats [:str, :agi, :vit, :int, :dex, :luk]

  @typedoc "A resolved link target: a registered player or the caster's live Homunculus."
  @type target :: {:player, PlayerState.t()} | {:homunculus, HomunculusState.t()}

  @doc "A caster holding a puppet's half is refused silently before anything else."
  @impl Active
  @spec skilluse_check(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :caster_restricted}
  def skilluse_check(%PlayerState{character_id: id}, _target, _level, _definition),
    do: reject_puppet_caster(id)

  def skilluse_check(_caster, _target, _level, _definition), do: :ok

  @doc """
  The cast end accepts a party member or the caster's own Homunculus; a dead
  target passes here and the use ends before this implementation runs.
  """
  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{} = caster, target, _level, _definition) do
    case resolve_target(caster, target) do
      {:ok, {:player, member}} -> validate_target(caster, member)
      {:ok, {:homunculus, _own}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
          | {:failed, PlayerState.t(), atom(), :spare_items}
          | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, target, _level, _definition) do
    with {:ok, resolved} <- resolve_target(caster, target) do
      case cast_gate(caster, resolved) do
        :ok -> resolve_link(caster, resolved, id)
        {:error, reason} -> {:failed, caster, reason, :spare_items}
      end
    end
  end

  # The reference refuses these inside its implementation, after the requirement
  # is paid, and clears SKILL_NOCONSUME_REQ's items on the way out. The
  # performer rule needs a player target; the Curse and Quagmire rule reads the
  # target's own status container, whichever unit it is.
  @spec cast_gate(PlayerState.t(), target()) :: :ok | {:error, atom()}
  defp cast_gate(caster, {:player, target}) do
    cond do
      caster.sex == target.sex and performer?(target) -> {:error, :invalid_target}
      blocked?(:player, target.character_id) -> {:error, :target_blocked}
      true -> :ok
    end
  end

  defp cast_gate(_caster, {:homunculus, homunculus}) do
    if blocked?(:homunculus, homunculus.world_gid), do: {:error, :target_blocked}, else: :ok
  end

  @spec reject_puppet_caster(non_neg_integer()) :: :ok | {:error, :caster_restricted}
  defp reject_puppet_caster(caster_id) do
    if StatusStorage.has_status?(:player, caster_id, :sc_marionette2),
      do: {:error, :caster_restricted},
      else: :ok
  end

  defp resolve_link(caster, resolved, caster_id) do
    {unit_type, unit_id} = target_ref(resolved)
    master = StatusStorage.get_status(:player, caster_id, :sc_marionette)
    puppet = StatusStorage.get_status(unit_type, unit_id, :sc_marionette2)

    cond do
      is_nil(master) and is_nil(puppet) ->
        link(caster, resolved)

      paired?(master, puppet, {:player, caster_id}, {unit_type, unit_id}) ->
        :ok =
          StatusInterpreter.remove_status(:player, caster_id, :sc_marionette,
            owner_refresh: :defer
          )

        {:ok, caster}

      true ->
        {:failed, caster, :already_linked, :spare_items}
    end
  end

  defp resolve_target(%PlayerState{character_id: caster_id}, {:unit, {:homunculus, gid}}) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok,
       {HomunculusState, %HomunculusState{owner_character_id: ^caster_id} = homunculus, _pid}} ->
        if Unit.living?(homunculus),
          do: {:ok, {:homunculus, homunculus}},
          else: {:error, :target_restricted}

      _foreign_or_gone ->
        {:error, :target_restricted}
    end
  end

  defp resolve_target(_caster, {:unit, target_id}) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, %PlayerState{} = target, _pid}} -> {:ok, {:player, target}}
      _ -> {:error, :invalid_target}
    end
  end

  defp resolve_target(_caster, _target), do: {:error, :invalid_target}

  defp target_ref({:player, target}), do: {:player, target.character_id}
  defp target_ref({:homunculus, homunculus}), do: {:homunculus, homunculus.world_gid}

  defp validate_target(caster, target) do
    cond do
      caster.character_id == target.character_id -> {:error, :invalid_target}
      not same_party?(caster, target) -> {:error, :not_same_party}
      true -> :ok
    end
  end

  @spec blocked?(atom(), integer()) :: boolean()
  defp blocked?(unit_type, unit_id) do
    StatusStorage.has_status?(unit_type, unit_id, :sc_curse) or
      StatusStorage.has_status?(unit_type, unit_id, :sc_quagmire)
  end

  defp same_party?(%PlayerState{party_id: party}, %PlayerState{party_id: party})
       when is_integer(party) and party > 0, do: true

  defp same_party?(_caster, _target), do: false

  defp performer?(%PlayerState{stats: %{progression: %{job_id: id}}}) do
    case AvailableJobs.job_id_to_name(id) do
      {:ok, job} -> JobLineage.base_job(job) in [:bard, :dancer]
      _ -> false
    end
  end

  defp paired?(
         %StatusEntry{state: %{peer: target_ref, link_id: link}},
         %StatusEntry{state: %{peer: caster_ref, link_id: link}},
         caster_ref,
         target_ref
       ),
       do: true

  defp paired?(_master, _puppet, _caster, _target), do: false

  defp link(caster, {:player, target}) do
    halves = Formulas.marionette_halves(caster.stats.base_stats)

    totals =
      Map.new(@primary_stats, &{&1, PlayerStats.get_effective_stat(target.stats, &1)})

    apply_pair(caster, {:player, target.character_id}, halves, totals)
  end

  defp link(caster, {:homunculus, homunculus}) do
    halves = Formulas.marionette_halves(caster.stats.base_stats)
    totals = Map.new(@primary_stats, &{&1, Map.fetch!(homunculus, &1)})

    apply_pair(caster, {:homunculus, homunculus.world_gid}, halves, totals)
  end

  defp apply_pair(caster, {puppet_type, puppet_id} = puppet_ref, halves, totals) do
    gains = Formulas.marionette_gains(halves, totals)
    link = make_ref()
    params = [caster_id: caster.character_id, duration: nil]

    # Both halves are started independently and a refused one is ignored, exactly
    # as the reference ignores both status results; the applied half retires on
    # its own tick when the peer is missing.
    StatusInterpreter.apply_status(
      :player,
      caster.character_id,
      :sc_marionette,
      params ++
        [
          state: %{peer: puppet_ref, link_id: link, halves: halves},
          owner_refresh: :defer
        ]
    )

    StatusInterpreter.apply_status(
      puppet_type,
      puppet_id,
      :sc_marionette2,
      params ++
        [
          state: %{peer: {:player, caster.character_id}, link_id: link, gains: gains}
        ]
    )

    {:ok, caster}
  end
end
