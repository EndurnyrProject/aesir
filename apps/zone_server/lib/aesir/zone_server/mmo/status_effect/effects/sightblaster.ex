defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sightblaster do
  @moduledoc """
  Sight Blaster (SC_SIGHTBLASTER).

  The caster is armed until an enemy is within one cell. It checks immediately
  and on 20ms status ticks, while movement contact uses the same trigger path.
  The first successful hit deals 600% Fire magic damage, knocks the target
  back, and consumes the status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sightblaster,
    properties: [:buff],
    duration: 900_000,
    tick_interval: 20,
    no_save: true,
    icon: :wz_sightblaster,
    option: :sight

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @skill_id 1006
  @skill_ratio 600
  @knockback 3

  @impl true
  def on_apply(target, instance, _context), do: trigger_nearby(target, instance)

  @impl true
  def on_tick(target, instance, _context), do: trigger_nearby(target, instance)

  @impl true
  def on_contact({:player, caster_id}, instance, {target_type, target_id}, _context) do
    with {:ok, {_module, caster, _pid}} <- UnitRegistry.get_unit(:player, caster_id),
         {:ok, {x, y, _map_name}} <- SpatialIndex.get_unit_position(:player, caster_id),
         :ok <-
           Combat.execute_magic_attack(caster, target_id,
             skill_id: @skill_id,
             skill_level: instance.val1,
             skill_ratio: @skill_ratio,
             element: :fire
           ) do
      _ = Combat.knockback(target_type, target_id, x, y, @knockback)
      :remove
    else
      {:error, _reason} -> {:ok, instance}
    end
  end

  @spec trigger_nearby({:player, integer()}, struct()) :: {:ok, struct()} | :remove
  defp trigger_nearby({:player, caster_id} = caster, instance) do
    case SpatialIndex.get_unit_position(:player, caster_id) do
      {:ok, {x, y, map_name}} ->
        trigger_contacts(caster, instance, map_name, x, y)

      {:error, _reason} ->
        {:ok, instance}
    end
  end

  @spec trigger_contacts({:player, integer()}, struct(), String.t(), integer(), integer()) ::
          {:ok, struct()} | :remove
  defp trigger_contacts(caster, instance, map_name, x, y) do
    map_name
    |> SpatialIndex.get_all_units_in_range(x, y, 1)
    |> Enum.reject(&(&1 == caster))
    |> Enum.reduce_while({:ok, instance}, &trigger_contact(caster, &1, &2))
  end

  @spec trigger_contact({:player, integer()}, {atom(), integer()}, {:ok, struct()}) ::
          {:cont, {:ok, struct()}} | {:halt, :remove}
  defp trigger_contact(caster, contact, {:ok, instance}) do
    case on_contact(caster, instance, contact, %{}) do
      :remove -> {:halt, :remove}
      {:ok, next_instance} -> {:cont, {:ok, next_instance}}
    end
  end
end
