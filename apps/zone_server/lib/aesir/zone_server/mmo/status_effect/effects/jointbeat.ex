defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Jointbeat do
  @moduledoc """
  Joint Beat (SC_JOINTBEAT) applies one of six persistent wound types for
  30 seconds. A neck break also causes Bleeding. Renewal and pre-renewal share
  these effects. Movement penalties stack additively with other slow sources,
  rather than taking only the strongest slow as in the reference rules.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_jointbeat,
    no_dispel: false,
    no_save: true,
    properties: [:debuff],
    calc_flags: [:batk, :def2, :speed, :aspd],
    icon: :jointbeat

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @breaks [:ankle, :wrist, :knee, :shoulder, :waist, :neck]

  @doc "The six wound types selected by Joint Beat."
  @spec breaks() :: [atom()]
  def breaks, do: @breaks

  @impl true
  def modifiers(%StatusEntry{val2: :ankle}, _context), do: %{movement_speed: 50}
  def modifiers(%StatusEntry{val2: :wrist}, _context), do: %{aspd_rate: -25}
  def modifiers(%StatusEntry{val2: :knee}, _context), do: %{movement_speed: 30, aspd_rate: -10}
  def modifiers(%StatusEntry{val2: :shoulder}, _context), do: %{def2_rate: -50}
  def modifiers(%StatusEntry{val2: :waist}, _context), do: %{def2_rate: -25, atk_rate: -25}
  def modifiers(%StatusEntry{val2: :neck}, _context), do: %{}

  @impl true
  def on_apply({unit_type, unit_id}, %StatusEntry{val2: :neck} = instance, _context) do
    _ =
      Interpreter.apply_status(unit_type, unit_id, :sc_bleeding,
        val1: instance.val1,
        duration: 30_000,
        caster_id: instance.source_id,
        source_type: instance.source_type || unit_type
      )

    {:ok, instance}
  end

  def on_apply(_target, instance, _context), do: {:ok, instance}
end
