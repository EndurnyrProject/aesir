defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica do
  @moduledoc """
  Pre-renewal Basilica occupant (SC_BASILICA in pre-renewal). `val1` is the
  skill level.

  Granted by the Basilica sanctuary: by its 300 ms unit pass to every non-enemy
  of its caster standing on it (any unit type), for the sanctuary's full
  lifetime, and to a player stepping or warping onto one of its cells, enemy or
  not, indefinitely (`val4` 0 marks that grant). As the last blocker, after Kyrie
  Eleison and Safety Wall, it blocks every attack still carrying damage unless
  the attacker is status-immune (a boss-class monster or one with the
  status-immune mode). The holder cannot attack or cast; it may still walk out.
  A player loses it on any step or warp onto another cell; any holder loses it
  when the sanctuary cell it stands on ends. It ends whenever its holder leaves its
  map (any warp, same map included) and is never saved. Dispel ends it too.

  Renewal Basilica is the `sc_basilica_buff` self buff; this status is only
  granted in pre-renewal. `absorb_damage/4` is shared with the caster lock,
  `sc_basilica_caster`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_basilica,
    no_save: true,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    remove_on_map_change: [renewal: false, pre_renewal: true],
    bypass_resistance: true,
    target_types: [:player, :mob, :homunculus],
    properties: [:prevents_attack, :prevents_skills],
    icon: :basilica

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "A player's grant on stepping onto a sanctuary cell (`val4` 0) never runs out."
  @impl true
  def resolve_duration(%StatusEntry{val4: 0} = instance, _duration), do: {nil, instance}
  def resolve_duration(instance, duration), do: {duration, instance}

  @doc """
  Blocks the hit unless its source is status-immune. A hit with no known source
  is blocked: traps and ground fields belong to ordinary owners.
  """
  @impl true
  def absorb_damage(_target, instance, %{attacker: {unit_type, unit_id}} = hit_info, _context) do
    if status_immune?(unit_type, unit_id),
      do: {:ok, hit_info.damage, instance},
      else: {:ok, 0, instance}
  end

  def absorb_damage(_target, instance, _hit_info, _context), do: {:ok, 0, instance}

  defp status_immune?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {MobState, %MobState{mob_data: %{modes: modes}}, _pid}} ->
        :status_immune in modes

      _not_a_mob ->
        false
    end
  end

  @doc """
  rAthena `pc_cell_basilica`, run on a player's walk step and warp arrival in
  pre-renewal: on a sanctuary cell a player without `sc_basilica` receives it
  indefinitely; anywhere else a player holding it loses it, and a sanctuary's
  caster moved off its cells ends the sanctuary.
  """
  @spec sync_cell_status(PlayerState.t()) :: :ok
  def sync_cell_status(%PlayerState{character_id: id, map_name: map_name, x: x, y: y}) do
    if GameMode.mode() == :pre_renewal do
      on_cell? = Storage.basilica?(map_name, x, y)

      # A sanctuary's caster holds its own lock, the source's SC_BASILICA.
      if StatusStorage.has_status?(:player, id, :sc_basilica_caster),
        do: sync_caster(id, on_cell?),
        else: sync_status(id, on_cell?, StatusStorage.has_status?(:player, id, :sc_basilica))
    end

    :ok
  end

  defp sync_caster(_id, true), do: :ok

  defp sync_caster(id, false),
    do: StatusInterpreter.remove_status(:player, id, :sc_basilica_caster, owner_refresh: :notify)

  # `duration` only satisfies the application; `val4: 0` makes
  # `resolve_duration/2` store the grant without an end.
  defp sync_status(id, true, false) do
    StatusInterpreter.apply_status(:player, id, :sc_basilica,
      val4: 0,
      duration: 1,
      caster_id: id,
      owner_refresh: :notify
    )
  end

  defp sync_status(id, false, true),
    do: StatusInterpreter.remove_status(:player, id, :sc_basilica, owner_refresh: :notify)

  defp sync_status(_id, _on_cell?, _held?), do: :ok
end
