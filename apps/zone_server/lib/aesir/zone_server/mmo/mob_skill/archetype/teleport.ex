defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.Teleport do
  @moduledoc """
  Instant self-reposition to a random walkable cell on the caster's map
  (`AL_TELEPORT`).

  rAthena's teleport is flee behavior: the caster vanishes and reappears
  elsewhere on the same map, dropping its current target. The archetype is a
  thin shim — `apply/4` runs synchronously inside the caster's `MobSession`
  process (from `:cast_complete`), so it self-casts `{:mob_teleport}` and lets
  the session perform the reposition after the current cast returns. The session
  reuses the `:knocked_back` instant position-set path (spatial-index update +
  delta-snapshot broadcast), not the walking `move_to`.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def apply(%MobState{process_pid: pid}, _target, _params, _level) when is_pid(pid) do
    MobSession.teleport(pid)
  end

  def apply(%MobState{}, _target, _params, _level), do: {:error, :no_process}
end
