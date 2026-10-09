defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Suffragium do
  @moduledoc """
  Suffragium (SC_SUFFRAGIUM). Reduces variable cast time by a percentage held in
  the entry state.

  Renewal: 5 plus 5 per level percent (10, 15, 20%), kept for the whole duration and
  not consumed by casting. Pre-renewal: 15 per level percent (15, 30, 45%), removed
  at the late timing computation after a valid cast attempt, even if the skill
  ignores status cast-time reductions.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_suffragium,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :suffragium

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode

  @impl true
  def on_apply(_target, instance, _context) do
    value = reduction(instance.val1)
    {:ok, %{instance | val2: value} |> put_state(:cast_time_reduction, value)}
  end

  @doc "Variable cast reduction in percent: 5 plus 5 per level in renewal, 15 per level in classic."
  @spec reduction(pos_integer()) :: pos_integer()
  def reduction(level) do
    case GameMode.mode() do
      :renewal -> 5 + level * 5
      :pre_renewal -> 15 * level
    end
  end
end
