defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Bloodlust do
  @moduledoc "Amistr's ATK status and typed post-basic-hit HP drain."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_bloodlust,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk],
    no_save: true,
    remove_on_map_change: true,
    icon: :hami_bloodlust

  @impl true
  def modifiers(instance, _context), do: %{atk_rate: instance.val2}

  @impl true
  def on_dealt_damage(
        {:homunculus, gid},
        instance,
        %{damage: damage, primary_basic_weapon_hit?: true},
        _context
      )
      when is_integer(damage) and damage > 0 do
    if :rand.uniform(100) <= instance.val3 do
      amount = div(damage * instance.val4, 100)

      if amount > 0 do
        {:ok, instance, [{:local_heal, {:homunculus, gid}, amount, {:homunculus, gid}}]}
      else
        {:ok, instance}
      end
    else
      {:ok, instance}
    end
  end

  def on_dealt_damage(_target, instance, _hit_info, _context), do: {:ok, instance}
end
