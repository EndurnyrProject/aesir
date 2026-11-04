defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgGraffiti do
  @moduledoc """
  Scribble (RG_GRAFFITI), a map-wide persistent ground marker.

  Both modes place one 3-minute graffiti per map for 15 SP and a Red Gemstone.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 220,
    name: :rg_graffiti,
    no_reiteration: true,
    requires: [:inventory],
    display_name: "Scribble",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 1,
    unit_duration: [180_000],
    sp_cost: [15],
    item_cost: [%{id: 716, amount: 1}],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active
  @behaviour Ground

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :graffiti_already_placed}
  def validate(%PlayerState{} = caster, target, level, definition) do
    case begin_attempt(caster, target, level, definition) do
      {:ok, _caster} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:ground, x, y}, level, definition),
    do: place(caster, {x, y}, level, definition, caster.skill_message, :direct)

  def cast(%MobState{} = caster, {:ground, x, y}, level, definition),
    do: place(caster, {x, y}, level, definition, "Boo!", :mob)

  def cast(_caster, _target, _level, _definition), do: {:error, :skill_input_required}

  @impl Active
  @spec cast_with_input(
          PlayerState.t(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          binary()
        ) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast_with_input(%PlayerState{} = caster, {:ground, x, y}, level, definition, text),
    do: place(caster, {x, y}, level, definition, text, :normal)

  def cast_with_input(_caster, _target, _level, _definition, _text), do: {:error, :invalid_target}

  defp place(caster, cell, level, definition, text, origin) do
    case Unit.place(caster, definition.name, level, cell, origin: origin, state: %{message: text}) do
      {:ok, _group} -> {:ok, caster}
      {:error, reason} -> if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  @doc "The cast begins only while no Graffiti stands anywhere on the caster's map."
  @impl Active
  @spec begin_attempt(map(), term(), pos_integer(), map()) ::
          {:ok, map()} | {:error, :graffiti_already_placed}
  def begin_attempt(
        %PlayerState{map_name: map_name} = caster,
        {:ground, _x, _y},
        _level,
        _definition
      ) do
    if Enum.any?(Storage.all(), &(&1.map_name == map_name and &1.skill_name == :rg_graffiti)) do
      {:error, :graffiti_already_placed}
    else
      {:ok, caster}
    end
  end

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center}) do
    {:ok, %{cells: [center], state: %{}, interval: 1_000, duration: 180_000}}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}
end
