defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoemBragi do
  @moduledoc "Finite Poem of Bragi cast-time and after-cast-delay snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poembragi,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:cast_time, :after_cast_delay],
    end_on_start: [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :poembragi

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok,
     put_state(instance, %{
       cast_time_reduction: instance.val2,
       delay_reduction: instance.val3
     })}
  end
end
