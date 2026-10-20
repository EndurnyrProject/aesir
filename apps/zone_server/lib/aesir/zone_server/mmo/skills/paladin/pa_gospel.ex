defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel do
  @moduledoc """
  Battle Chant (PA_GOSPEL). The Paladin plants a 33-cell thick cross (seven
  long, three wide) at their feet for 60 seconds and chants: rooted, unable to
  cast anything but Gospel itself, paying HP and SP every 10 seconds (see
  `StatusEffect.Effects.Gospel`). Starting the chant wipes the caster's buffs
  and debuffs. Recasting while chanting ends the chant and spares the skill's
  items; its SP is spent like any other cast. 80 SP at levels 1-5, 100 SP at
  6-10.

  Each field cell is a unit acting on the 100 ms unit pass: a unit standing on
  the field other than the caster is struck once every 10 seconds, starting
  from the first pass, and has a `50 + 5 * level` percent chance to receive one
  random effect: party members (and party homunculi) a blessing, enemies an
  affliction (`PaGospel.Tick` and `PaGospel.Effects`). The interval is shared
  by every Gospel. A cell on Land Protector does nothing. Two Gospels may not
  overlap; the skill-unit manager refuses the second before the cast is paid.

  A dropped footprint leaves neither field nor chant, and a refused chant status
  keeps the field without wiping anything: the wipe runs inside the status start.

  Identical in both game modes except the enemy slow's attack-speed magnitude
  (`StatusEffect.Effects.GospelSlow`). Player-only: no monster casts it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 369,
    name: :pa_gospel,
    requires: [],
    status: :sc_gospel,
    display_name: "Battle Chant",
    max_level: 10,
    ignore_flee: true,
    target_type: :self,
    sp_cost: [80, 80, 80, 80, 80, 100, 100, 100, 100, 100],
    duration: List.duplicate(60_000, 10),
    damage_kind: :misc

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Tick
  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit, as: AesirUnit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground

  @duration 60_000
  @interval 10_000

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:ok, Active.caster(), :no_consume} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, _target, level, _definition) do
    if chanting?(id) do
      StatusInterpreter.remove_status(:player, id, :sc_gospel)
      {:ok, caster, :no_consume}
    else
      start_chant(caster, level)
    end
  end

  def cast(%MobState{}, _target, _level, _definition), do: {:error, :player_only}

  @doc "The 33 cells of the Gospel footprint: a seven-long, three-wide cross around `center`."
  @spec thick_cross({integer(), integer()}) :: [Ground.cell()]
  def thick_cross({cx, cy}) do
    for dx <- -3..3, dy <- -3..3, abs(dx) <= 1 or abs(dy) <= 1, do: {cx + dx, cy + dy}
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center}) do
    {:ok,
     %{
       cells: thick_cross(center),
       state: %{},
       interval: @interval,
       duration: @duration,
       unit_range: 0,
       no_overlap: true
     }}
  end

  # A field whose Paladin is gone ends; one standing empty is still checked.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{caster_type: type, caster_id: id} = group, _now) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, _caster} -> {:ok, group}
      _gone -> {:expire, group}
    end
  end

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [Ref.t()]) :: [Ref.t()]
  def unit_targets(%Group{caster_type: type, caster_id: id}, _cell, refs),
    do: Enum.filter(refs, &(&1 != {type, id} and living?(&1)))

  defp living?({type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, _pid}} -> AesirUnit.living?(state)
      _gone -> false
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), Ref.t(), integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, _now) do
    Tick.strike(group, target)
    {:ok, group}
  end

  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{caster_id: caster_id}) do
    StatusInterpreter.remove_status(:player, caster_id, :sc_gospel, owner_refresh: :notify)
    :ok
  end

  defp chanting?(id), do: StatusStorage.has_status?(:player, id, :sc_gospel)

  # A dropped footprint leaves neither field nor chant: the requirement stays
  # paid and its items are consumed, while the manager's reiteration refusal is
  # raised before the cast is charged.
  defp start_chant(%PlayerState{x: x, y: y} = caster, level) do
    case Unit.place(caster, :pa_gospel, level, {x, y}) do
      {:ok, group} ->
        lock(caster, level, group)

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  # A refused chant status keeps the field and the requirement: the reference
  # ignores the status result, and its wipe runs inside the status start, so a
  # refused status leaves the caster's buffs and debuffs alone. The wipe spares
  # the chant, which the reference stores only after the wipe has run.
  defp lock(%PlayerState{character_id: id} = caster, level, %Group{group_id: group_id}) do
    params = [val1: level, val2: group_id, duration: @duration, caster_id: id]

    case StatusInterpreter.apply_status(:player, id, :sc_gospel, params) do
      :ok ->
        ClearBuffs.clear({:player, id}, [:buffs, :debuffs, :chem_protect], except: [:sc_gospel])

        {:ok, caster}

      {:error, _reason} ->
        {:ok, caster}
    end
  end
end
