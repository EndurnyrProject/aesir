defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Jointbeat do
  @moduledoc """
  Joint Beat (SC_JOINTBEAT) wounds for 30 seconds. Wounds stack: `val2` holds
  every broken part as a bitmask (`flag/1`), and each new break joins the held
  ones. A broken ankle and knee slow movement by 50 and 30, a wrist and knee
  lower the attack speed rate by 25 and 10, a shoulder and waist lower soft DEF
  by 50 and 25 percent, a waist lowers ATK by 25 percent, and a neck break
  starts Bleeding. While the neck is broken no new wound lands. Renewal and
  pre-renewal share these effects.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_jointbeat,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    no_save: true,
    properties: [:debuff],
    calc_flags: [:batk, :def2, :speed, :aspd],
    icon: :jointbeat

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @flags %{ankle: 0x01, wrist: 0x02, knee: 0x04, shoulder: 0x08, waist: 0x10, neck: 0x20}

  @doc "The bit of one broken part."
  @spec flag(:ankle | :wrist | :knee | :shoulder | :waist | :neck) :: pos_integer()
  def flag(part), do: Map.fetch!(@flags, part)

  @doc "The six single-part breaks Joint Beat chooses from, as bits."
  @spec breaks() :: [pos_integer()]
  def breaks, do: Enum.map([:ankle, :wrist, :knee, :shoulder, :waist, :neck], &flag/1)

  @doc "Whether the wound bitmask includes a broken `part`."
  @spec broken?(integer(), atom()) :: boolean()
  def broken?(wounds, part) when is_integer(wounds), do: Bitwise.band(wounds, flag(part)) != 0
  def broken?(_wounds, _part), do: false

  @impl true
  def modifiers(%StatusEntry{val2: wounds}, _context) do
    %{
      movement_speed: part(wounds, :ankle, 50) + part(wounds, :knee, 30),
      aspd_rate: -(part(wounds, :wrist, 25) + part(wounds, :knee, 10)),
      def2_rate: -(part(wounds, :shoulder, 50) + part(wounds, :waist, 25)),
      atk_rate: -part(wounds, :waist, 25)
    }
    |> Map.reject(fn {_key, value} -> value == 0 end)
  end

  defp part(wounds, part, value), do: if(broken?(wounds, part), do: value, else: 0)

  # A broken neck refuses new wounds; otherwise the new break joins the held
  # ones, unless the held wound is of a higher level.
  @impl true
  def overlap(_target, %StatusEntry{val2: held} = held_entry, incoming) do
    if broken?(held, :neck) do
      :fail
    else
      merged = %{incoming | val2: Bitwise.bor(incoming.val2, held)}

      case Definition.level_overlap(metadata(), held_entry, merged) do
        :replace -> {:replace, merged}
        :keep -> :keep
      end
    end
  end

  @impl true
  def on_apply({unit_type, unit_id}, %StatusEntry{val2: wounds} = instance, _context) do
    if broken?(wounds, :neck) do
      _ =
        Interpreter.apply_status(unit_type, unit_id, :sc_bleeding,
          val1: instance.val1,
          duration: 30_000,
          caster_id: instance.source_id,
          source_type: instance.source_type || unit_type
        )
    end

    {:ok, instance}
  end
end
