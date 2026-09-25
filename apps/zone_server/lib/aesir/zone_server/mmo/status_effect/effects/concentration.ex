defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Concentration do
  @moduledoc """
  Concentration (SC_CONCENTRATION).

  Both modes grant `10 × level` HIT and level-one Endure. Renewal raises ATK
  and reduces hard/soft DEF by `(5 + 2 × level)%`; pre-renewal uses `5 × level%`.
  Expiry removes finite Endure, leaving an independent infinite Endure active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_concentration,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:hit, :def],
    icon: :lkconcentration

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  def modifiers(instance, _context) do
    pct = if GameMode.mode() == :renewal, do: 5 + 2 * instance.val1, else: 5 * instance.val1
    %{atk_rate: pct, def_rate: -pct, def2_rate: -pct, hit: 10 * instance.val1}
  end

  @impl true
  def on_apply({unit_type, unit_id}, instance, _context) do
    duration =
      if instance.expires_at,
        do: max(instance.expires_at - System.monotonic_time(:millisecond), 1),
        else: nil

    case StatusStorage.get_status(unit_type, unit_id, :sc_endure) do
      %StatusEntry{val4: val4} when val4 != 0 ->
        :ok

      _ ->
        Interpreter.apply_status(unit_type, unit_id, :sc_endure,
          caster_id: instance.source_id,
          source_type: instance.source_type || unit_type,
          val1: 1,
          duration: duration
        )
    end

    {:ok, instance}
  end

  @impl true
  def on_expire({unit_type, unit_id}, _instance, _context) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_endure) do
      %StatusEntry{val4: 0} -> Interpreter.remove_status(unit_type, unit_id, :sc_endure)
      _ -> :ok
    end
  end
end
