defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgMarionette do
  @moduledoc """
  Marionette Control links one party member within seven cells in both modes.

  The master loses frozen halves of each base primary stat and one thousand
  MaxHP; the puppet gains those halves, capped against their total stats at
  ninety-nine. Both halves tick until removed or the pair separates. Recasting
  on the current puppet ends the link.

  Self, non-party, and a caster already wearing a puppet's half are refused
  before the cost. The same-sex performer, cursed and quagmired refusals happen
  inside the implementation, after the requirement is paid, and spare the
  skill's items, as does a cast onto a participant of another link. A refused
  half of the pair is ignored; the applied half retires on its own tick when its
  peer is missing.
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
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{character_id: id} = caster, {:unit, target_id}, _level, _definition) do
    with {:ok, target} <- target_player(target_id),
         :ok <- reject_puppet_caster(id) do
      validate_target(caster, target)
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
          | {:failed, PlayerState.t(), atom(), :spare_items}
          | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, {:unit, target_id}, _level, _definition) do
    with {:ok, target} <- target_player(target_id) do
      case cast_gate(caster, target) do
        :ok -> resolve_link(caster, target, id, target_id)
        {:error, reason} -> {:failed, caster, reason, :spare_items}
      end
    end
  end

  # The reference refuses these inside its implementation, after the requirement
  # is paid, and clears SKILL_NOCONSUME_REQ's items on the way out.
  @spec cast_gate(PlayerState.t(), PlayerState.t()) :: :ok | {:error, atom()}
  defp cast_gate(caster, target) do
    cond do
      caster.sex == target.sex and performer?(target) -> {:error, :invalid_target}
      blocked?(target) -> {:error, :target_blocked}
      true -> :ok
    end
  end

  # A caster that holds a puppet's half cannot use Marionette at all; the
  # reference blocks it before the cost is spent.
  @spec reject_puppet_caster(non_neg_integer()) :: :ok | {:error, :invalid_target}
  defp reject_puppet_caster(caster_id) do
    if StatusStorage.has_status?(:player, caster_id, :sc_marionette2),
      do: {:error, :invalid_target},
      else: :ok
  end

  defp resolve_link(caster, target, caster_id, target_id) do
    master = StatusStorage.get_status(:player, caster_id, :sc_marionette)
    puppet = StatusStorage.get_status(:player, target_id, :sc_marionette2)

    cond do
      is_nil(master) and is_nil(puppet) ->
        link(caster, target)

      paired?(master, puppet, caster_id, target_id) ->
        :ok =
          StatusInterpreter.remove_status(:player, caster_id, :sc_marionette,
            owner_refresh: :defer
          )

        {:ok, caster}

      true ->
        {:failed, caster, :already_linked, :spare_items}
    end
  end

  defp target_player(id) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, %PlayerState{} = target, _pid}} ->
        if Unit.living?(target), do: {:ok, target}, else: {:error, :invalid_target}

      _ ->
        {:error, :invalid_target}
    end
  end

  defp validate_target(caster, target) do
    cond do
      caster.character_id == target.character_id -> {:error, :invalid_target}
      not same_party?(caster, target) -> {:error, :not_same_party}
      true -> :ok
    end
  end

  @spec blocked?(PlayerState.t()) :: boolean()
  defp blocked?(%PlayerState{character_id: id}) do
    StatusStorage.has_status?(:player, id, :sc_curse) or
      StatusStorage.has_status?(:player, id, :sc_quagmire)
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
         %StatusEntry{state: %{peer: {:player, target}, link_id: link}},
         %StatusEntry{state: %{peer: {:player, caster}, link_id: link}},
         caster,
         target
       ),
       do: true

  defp paired?(_master, _puppet, _caster, _target), do: false

  defp link(caster, target) do
    halves = Formulas.marionette_halves(caster.stats.base_stats)
    totals = Map.new(Map.keys(halves), &{&1, PlayerStats.get_effective_stat(target.stats, &1)})
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
          state: %{peer: {:player, target.character_id}, link_id: link, halves: halves},
          owner_refresh: :defer
        ]
    )

    StatusInterpreter.apply_status(
      :player,
      target.character_id,
      :sc_marionette2,
      params ++
        [
          state: %{peer: {:player, caster.character_id}, link_id: link, gains: gains},
          owner_refresh: :notify
        ]
    )

    {:ok, caster}
  end
end
