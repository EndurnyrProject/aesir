defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel do
  @moduledoc """
  Battle Chant (PA_GOSPEL). The Paladin plants a 33-cell thick cross (seven
  long, three wide) at their feet for 60 seconds and chants: rooted, unable to
  cast anything but Gospel itself, paying HP and SP every 10 seconds (see
  `StatusEffect.Effects.Gospel`). Once the field is accepted the caster's buffs
  and debuffs are wiped. Recasting while chanting ends the chant and costs
  nothing. 80 SP at
  levels 1-5, 100 SP at 6-10.

  Each field cell is a unit acting on the 100 ms unit pass: a unit standing on
  the field other than the caster is struck once every 10 seconds, starting
  from the first pass, and has a `50 + 5 * level` percent chance to receive one
  random effect: party members (and party homunculi) a blessing, enemies an
  affliction (`PaGospel.Tick` and `PaGospel.Effects`). The interval is shared
  by every Gospel. A cell on Land Protector does nothing. Two Gospels may not
  overlap; the skill-unit manager refuses the second.

  Identical in both game modes except the enemy slow's attack-speed magnitude
  (`StatusEffect.Effects.GospelSlow`). Player-only: no monster casts it.

  Accepted deviation: a magic-immune caster keeps their statuses (the wipe is
  skipped) but still chants; the reference wipes regardless.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 369,
    name: :pa_gospel,
    requires: [],
    status: :sc_gospel,
    display_name: "Battle Chant",
    max_level: 10,
    target_type: :self,
    sp_cost: [80, 80, 80, 80, 80, 100, 100, 100, 100, 100],
    duration: List.duplicate(60_000, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
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
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, _target, level, _definition) do
    if chanting?(id) do
      StatusInterpreter.remove_status(:player, id, :sc_gospel)
      {:ok, caster}
    else
      start_chant(caster, level)
    end
  end

  def cast(%MobState{}, _target, _level, _definition), do: {:error, :player_only}

  @doc "Recasting to end the chant costs nothing; starting one costs the listed SP."
  @impl Active
  @spec dynamic_cost(Active.caster(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(%PlayerState{character_id: id} = caster, _target, level, definition) do
    sp = if chanting?(id), do: 0, else: Cost.resolve_sp(caster, definition, level)
    Cost.from_definition(caster, definition, level, sp: sp)
  end

  def dynamic_cost(caster, _target, level, definition),
    do: Cost.from_definition(caster, definition, level)

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

  # The wipe runs only once the field is accepted, so a refused placement (an
  # overlapping Gospel) leaves the caster's statuses alone.
  defp start_chant(%PlayerState{character_id: id, x: x, y: y} = caster, level) do
    with {:ok, group} <- Unit.place(caster, :pa_gospel, level, {x, y}) do
      ClearBuffs.clear({:player, id}, [:buffs, :debuffs, :chem_protect])
      lock(caster, level, group)
    end
  end

  defp lock(%PlayerState{character_id: id} = caster, level, %Group{group_id: group_id}) do
    params = [val1: level, val2: group_id, duration: @duration, caster_id: id]

    case StatusInterpreter.apply_status(:player, id, :sc_gospel, params) do
      :ok ->
        {:ok, caster}

      {:error, _reason} = error ->
        Unit.destroy_async(group_id)
        error
    end
  end
end
