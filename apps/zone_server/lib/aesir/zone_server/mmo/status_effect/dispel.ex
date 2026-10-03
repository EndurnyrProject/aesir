defmodule Aesir.ZoneServer.Mmo.StatusEffect.Dispel do
  @moduledoc """
  Strips every dispellable status from a unit (rAthena's Dispell removal loop).

  Mirrors `src/map/skills/mage/dispell.cpp:36-72`, which iterates the whole
  `status_db` and ends every status the target has except those flagged
  `SCF_NODISPELL`. There is **no buff/debuff distinction**: Poison, Stun,
  Curse, Silence, Blind, Bleeding, Freeze and Stone are all dispelled. The
  disposition therefore reads the `no_dispel` metadata key (audited against
  rAthena's `NoDispell` entries), never `PropertyChecker.buff?/1`.

  Removal is delegated as one batch to `Interpreter.remove_statuses/4` so that
  `on_expire`, icon deltas and calc-flag recomputation fire exactly as they do
  on natural expiry, rather than deleting ETS rows directly and bypassing
  those side effects.

  Deviations from the reference, all deliberate:

  * **No song-area special case.** The reference keeps the bard/dancer songs
    alive while the target still stands in the song's area. The branch is
    unreachable in renewal anyway: every song in that list is flagged
    no-dispel, so the preceding flag check already skips them, and Aesir's
    `sc_poembragi` mirrors that.
  * **No Saturday Night Fever HP-penalty guard.** That status is not implemented;
    Berserk's expiry penalty is disarmed before removal.
  * **No `bonus_script` clearing** (`BSF_REM_ON_DISPELL`): Aesir has no
    bonus-script system.

  Mob targets additionally drop their aggro target and fall back to idle,
  rAthena's `mob_unlocktarget`. Assumptio is spared on mobs (players lose it as
  usual).

  `dispel_debuffs/1` is the debuff-only variant used by Gospel's cleansing
  blessing: buffs and `no_dispel` debuffs stay.
  """
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @penalty_on_expire [:sc_berserk]

  @doc """
  Removes every status on the target whose definition lacks `no_dispel`.
  Magic-immune targets are left unchanged.

  A dispelled mob also drops its aggro target. Casts are untouched: rAthena's
  Dispell does not interrupt a cast in progress. Player owners receive exactly
  one asynchronous refresh after the whole removal batch.
  """
  @spec dispel(Definition.target()) :: :ok | {:error, :magic_immune}
  def dispel({unit_type, unit_id} = target) do
    if MagicDefense.immune?(target) do
      {:error, :magic_immune}
    else
      status_ids =
        unit_type
        |> StatusStorage.get_unit_statuses(unit_id)
        |> Enum.reject(&no_dispel?/1)
        |> Enum.map(& &1.type)
        |> spare_mob_assumptio(unit_type)

      disarm_penalties(unit_type, unit_id, status_ids)
      Interpreter.remove_statuses(unit_type, unit_id, status_ids, owner_refresh: :notify)

      unlock_target(target)
    end
  end

  @doc """
  Removes every dispellable debuff from the target and nothing else.

  Gospel's cleansing blessing: buffs stay, `no_dispel` debuffs stay, and the
  removal batch runs the same expiry side effects as `dispel/1`.
  """
  @spec dispel_debuffs(Definition.target()) :: :ok
  def dispel_debuffs({unit_type, unit_id}) do
    status_ids =
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.reject(&no_dispel?/1)
      |> Enum.map(& &1.type)
      |> Enum.filter(&PropertyChecker.debuff?/1)

    Interpreter.remove_statuses(unit_type, unit_id, status_ids, owner_refresh: :notify)
  end

  defp spare_mob_assumptio(status_ids, :mob), do: List.delete(status_ids, :sc_assumptio)
  defp spare_mob_assumptio(status_ids, _unit_type), do: status_ids

  defp disarm_penalties(unit_type, unit_id, status_ids) do
    Enum.each(status_ids, fn id ->
      if id in @penalty_on_expire do
        StatusStorage.update_status(
          unit_type,
          unit_id,
          id,
          &Helpers.put_state(&1, :penalty_armed, false)
        )
      end
    end)
  end

  @spec no_dispel?(Aesir.ZoneServer.Mmo.StatusEntry.t()) :: boolean()
  defp no_dispel?(%{type: status_id}) do
    %{no_dispel: no_dispel} = Registry.get_definition(status_id)
    no_dispel
  end

  @spec unlock_target(Definition.target()) :: :ok
  defp unlock_target({:mob, unit_id}) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} -> MobSession.set_target(pid, nil)
      {:error, :not_found} -> :ok
    end
  end

  defp unlock_target({_unit_type, _unit_id}), do: :ok
end
