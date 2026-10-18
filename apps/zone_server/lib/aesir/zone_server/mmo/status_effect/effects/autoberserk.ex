defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoberserk do
  @moduledoc """
  Auto Berserk checks HP every 100 ms in both modes.

  At or below a quarter of maximum HP it grants level 10 infinite Provoke,
  marked as automatic. Healing above that threshold, ending Auto Berserk, or
  leaving the map removes that Provoke, not an ordinary taunt. Death also
  ends Auto Berserk itself.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autoberserk,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    permanent: true,
    remove_on_death: true,
    tick_interval: 100,
    icon: :autoberserk

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()}
  def on_tick({type, id}, instance, %{target: %{hp: hp, max_hp: max_hp}}) do
    case StatusStorage.get_status(type, id, :sc_provoke) do
      %{val4: 1} ->
        if hp > div(max_hp, 4), do: Interpreter.remove_status(type, id, :sc_provoke)

      _ordinary_or_missing ->
        if hp <= div(max_hp, 4), do: provoke(type, id)
    end

    {:ok, instance}
  end

  defp provoke(type, id) do
    {atk, defense} = if type == :player, do: {32, 55}, else: {0, 100}

    Interpreter.apply_status(type, id, :sc_provoke,
      val1: 10,
      val2: atk,
      val3: defense,
      val4: 1,
      caster_id: id,
      source_type: type,
      duration: -1,
      no_avoid: true
    )
  end

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire({type, id}, _instance, _context) do
    if match?(%{val4: 1}, StatusStorage.get_status(type, id, :sc_provoke)),
      do: Interpreter.remove_status(type, id, :sc_provoke)

    :ok
  end
end
