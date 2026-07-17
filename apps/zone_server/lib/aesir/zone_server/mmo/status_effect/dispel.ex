defmodule Aesir.ZoneServer.Mmo.StatusEffect.Dispel do
  @moduledoc """
  Strips every dispellable status from a unit (rAthena's Dispell removal loop).

  Mirrors `src/map/skills/mage/dispell.cpp:36-72`, which iterates the whole
  `status_db` and ends every status the target has except those flagged
  `SCF_NODISPELL`. There is **no buff/debuff distinction**: Poison, Stun,
  Curse, Silence, Blind, Bleeding, Freeze and Stone are all dispelled. The
  disposition therefore reads the `no_dispel` metadata key (audited against
  rAthena's `NoDispell` entries), never `PropertyChecker.buff?/1`.

  Removal is delegated per status to `Interpreter.remove_status/3` so that
  `on_expire`, icon deltas and calc-flag recomputation fire exactly as they do
  on natural expiry. `StatusStorage.clear_status_types/3` is deliberately not
  used: it deletes ETS rows behind the interpreter's back and classifies by
  `buff?/1`.

  Deviations from the reference, all deliberate:

  * **No `status_isimmune` gate.** rAthena aborts the whole removal when the
    target has full magic immunity (GTB card, `dispell.cpp:33`). Aesir has no
    `status_isimmune` equivalent, so nothing is checked here; add the gate at
    this call site if that mechanic ever lands.
  * **No song-area or Assumptio special cases.** `dispell.cpp:56-66` keeps the
    bard/dancer songs alive while the target still stands in the song's area
    (`val4 == 0`) and spares Assumptio on mobs. The song branch is unreachable
    in renewal anyway - `db/re/status.yml` flags every song in that list
    `NoDispell: true`, so the preceding flag check already skips them, and
    Aesir's `sc_poembragi` mirrors that. Assumptio is not implemented.
  * **No Berserk HP-penalty guard.** `dispell.cpp:68-69` zeroes
    `SC_BERSERK`/`SC_SATURDAYNIGHTFEVER`'s `val2` before ending them so the
    end handler skips its HP penalty. Neither status is implemented in Aesir;
    a future Berserk must zero its penalty here.
  * **No `bonus_script` clearing** (`BSF_REM_ON_DISPELL`): Aesir has no
    bonus-script system.

  Mob targets additionally drop their aggro target and fall back to idle,
  rAthena's `mob_unlocktarget`.
  """
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Removes every status on the target whose definition lacks `no_dispel`.

  A dispelled mob also drops its aggro target. Casts are untouched: rAthena's
  Dispell does not interrupt a cast in progress.
  """
  @spec dispel(Definition.target()) :: :ok
  def dispel({unit_type, unit_id} = target) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.reject(&no_dispel?/1)
    |> Enum.each(&Interpreter.remove_status(unit_type, unit_id, &1.type))

    unlock_target(target)
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
